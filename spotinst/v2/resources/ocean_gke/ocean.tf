#####################################################################
#
#                           OCEAN
#
#####################################################################
resource "spotinst_ocean_gke_launch_spec" "v2" {
  ocean_id = "o-978b0eef"
  service_account = "default"
  source_image = "https://www.googleapis.com/compute/v1/projects/gke-node-images/global/images/gke-1118-gke6-cos-69-10895-138-0-v190330-pre"

  metadata = [
    {
      key = "gci-update-strategy"
      value = "update_disabled"
    },
    {
      key = "gci-ensure-gke-docker"
      value = "true"
    },
        {
          key = "configure-sh"
          value = "#!/usr/bin/env bash\n\n# Copyright 2016 The Kubernetes Authors.\n#\n# Licensed under the Apache License, Version 2.0 (the \"License\");\n# you may not use this file except in compliance with the License.\n# You may obtain a copy of the License at\n#\n#     http://www.apache.org/licenses/LICENSE-2.0\n#\n# Unless required by applicable law or agreed to in writing, software\n# distributed under the License is distributed on an \"AS IS\" BASIS,\n# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n# See the License for the specific language governing permissions and\n# limitations under the License.\n\n# Due to the GCE custom metadata size limit, we split the entire script into two\n# files configure.sh and configure-helper.sh. The functionality of downloading\n# kubernetes configuration, manifests, docker images, and binary files are\n# put in configure.sh, which is uploaded via GCE custom metadata.\n\nset -o errexit\nset -o nounset\nset -o pipefail\n\n### Hardcoded constants\nDEFAULT_CNI_VERSION=\"v0.6.0\"\nDEFAULT_CNI_SHA1=\"d595d3ded6499a64e8dac02466e2f5f2ce257c9f\"\nDEFAULT_NPD_VERSION=\"v0.6.0\"\nDEFAULT_NPD_SHA1=\"a28e960a21bb74bc0ae09c267b6a340f30e5b3a6\"\nDEFAULT_CRICTL_VERSION=\"v1.11.1\"\nDEFAULT_CRICTL_SHA1=\"527fca5a0ecef6a8e6433e2af9cf83f63aff5694\"\nDEFAULT_MOUNTER_TAR_SHA=\"8003b798cf33c7f91320cd6ee5cec4fa22244571\"\n###\n\n# Use --retry-connrefused opt only if it's supported by curl.\nCURL_RETRY_CONNREFUSED=\"\"\nif curl --help | grep -q -- '--retry-connrefused'; then\n  CURL_RETRY_CONNREFUSED='--retry-connrefused'\nfi\n\nfunction set-broken-motd {\n  cat > /etc/motd <<EOF\nBroken (or in progress) Kubernetes node setup! Check the cluster initialization status\nusing the following commands.\n\nMaster instance:\n  - sudo systemctl status kube-master-installation\n  - sudo systemctl status kube-master-configuration\n\nNode instance:\n  - sudo systemctl status kube-node-installation\n  - sudo systemctl status kube-node-configuration\nEOF\n}\n\nfunction download-kube-env {\n  # Fetch kube-env from GCE metadata server.\n  (\n    umask 077\n    local -r tmp_kube_env=\"/tmp/kube-env.yaml\"\n    curl --fail --retry 5 --retry-delay 3 $${CURL_RETRY_CONNREFUSED} --silent --show-error \\\n      -H \"X-Google-Metadata-Request: True\" \\\n      -o \"$${tmp_kube_env}\" \\\n      http://metadata.google.internal/computeMetadata/v1/instance/attributes/kube-env\n    # Convert the yaml format file into a shell-style file.\n    eval $(python -c '''\nimport pipes,sys,yaml\nfor k,v in yaml.load(sys.stdin).iteritems():\n  print(\"readonly {var}={value}\".format(var = k, value = pipes.quote(str(v))))\n''' < \"$${tmp_kube_env}\" > \"$${KUBE_HOME}/kube-env\")\n    rm -f \"$${tmp_kube_env}\"\n  )\n}\n\nfunction download-kubelet-config {\n  local -r dest=\"$1\"\n  echo \"Downloading Kubelet config file, if it exists\"\n  # Fetch kubelet config file from GCE metadata server.\n  (\n    umask 077\n    local -r tmp_kubelet_config=\"/tmp/kubelet-config.yaml\"\n    if curl --fail --retry 5 --retry-delay 3 $${CURL_RETRY_CONNREFUSED} --silent --show-error \\\n        -H \"X-Google-Metadata-Request: True\" \\\n        -o \"$${tmp_kubelet_config}\" \\\n        http://metadata.google.internal/computeMetadata/v1/instance/attributes/kubelet-config; then\n      # only write to the final location if curl succeeds\n      mv \"$${tmp_kubelet_config}\" \"$${dest}\"\n    elif [[ \"$${REQUIRE_METADATA_KUBELET_CONFIG_FILE:-false}\" == \"true\" ]]; then\n      echo \"== Failed to download required Kubelet config file from metadata server ==\"\n      exit 1\n    fi\n  )\n}\n\nfunction download-kube-master-certs {\n  # Fetch kube-env from GCE metadata server.\n  (\n    umask 077\n    local -r tmp_kube_master_certs=\"/tmp/kube-master-certs.yaml\"\n    curl --fail --retry 5 --retry-delay 3 $${CURL_RETRY_CONNREFUSED} --silent --show-error \\\n      -H \"X-Google-Metadata-Request: True\" \\\n      -o \"$${tmp_kube_master_certs}\" \\\n      http://metadata.google.internal/computeMetadata/v1/instance/attributes/kube-master-certs\n    # Convert the yaml format file into a shell-style file.\n    eval $(python -c '''\nimport pipes,sys,yaml\nfor k,v in yaml.load(sys.stdin).iteritems():\n  print(\"readonly {var}={value}\".format(var = k, value = pipes.quote(str(v))))\n''' < \"$${tmp_kube_master_certs}\" > \"$${KUBE_HOME}/kube-master-certs\")\n    rm -f \"$${tmp_kube_master_certs}\"\n  )\n}\n\nfunction validate-hash {\n  local -r file=\"$1\"\n  local -r expected=\"$2\"\n\n  actual=$(sha1sum $${file} | awk '{ print $1 }') || true\n  if [[ \"$${actual}\" != \"$${expected}\" ]]; then\n    echo \"== $${file} corrupted, sha1 $${actual} doesn't match expected $${expected} ==\"\n    return 1\n  fi\n}\n\n# Retry a download until we get it. Takes a hash and a set of URLs.\n#\n# $1 is the sha1 of the URL. Can be \"\" if the sha1 is unknown.\n# $2+ are the URLs to download.\nfunction download-or-bust {\n  local -r hash=\"$1\"\n  shift 1\n\n  local -r urls=( $* )\n  while true; do\n    for url in \"$${urls[@]}\"; do\n      local file=\"$${url##*/}\"\n      rm -f \"$${file}\"\n      if ! curl -f --ipv4 -Lo \"$${file}\" --connect-timeout 20 --max-time 300 --retry 6 --retry-delay 10 $${CURL_RETRY_CONNREFUSED} \"$${url}\"; then\n        echo \"== Failed to download $${url}. Retrying. ==\"\n      elif [[ -n \"$${hash}\" ]] && ! validate-hash \"$${file}\" \"$${hash}\"; then\n        echo \"== Hash validation of $${url} failed. Retrying. ==\"\n      else\n        if [[ -n \"$${hash}\" ]]; then\n          echo \"== Downloaded $${url} (SHA1 = $${hash}) ==\"\n        else\n          echo \"== Downloaded $${url} ==\"\n        fi\n        return\n      fi\n    done\n  done\n}\n\nfunction is-preloaded {\n  local -r key=$1\n  local -r value=$2\n  grep -qs \"$${key},$${value}\" \"$${KUBE_HOME}/preload_info\"\n}\n\nfunction split-commas {\n  echo $1 | tr \",\" \"\\n\"\n}\n\nfunction remount-flexvolume-directory {\n  local -r flexvolume_plugin_dir=$1\n  mkdir -p $flexvolume_plugin_dir\n  mount --bind $flexvolume_plugin_dir $flexvolume_plugin_dir\n  mount -o remount,exec $flexvolume_plugin_dir\n}\n\nfunction install-gci-mounter-tools {\n  CONTAINERIZED_MOUNTER_HOME=\"$${KUBE_HOME}/containerized_mounter\"\n  local -r mounter_tar_sha=\"$${DEFAULT_MOUNTER_TAR_SHA}\"\n  if is-preloaded \"mounter\" \"$${mounter_tar_sha}\"; then\n    echo \"mounter is preloaded.\"\n    return\n  fi\n\n  echo \"Downloading gci mounter tools.\"\n  mkdir -p \"$${CONTAINERIZED_MOUNTER_HOME}\"\n  chmod a+x \"$${CONTAINERIZED_MOUNTER_HOME}\"\n  mkdir -p \"$${CONTAINERIZED_MOUNTER_HOME}/rootfs\"\n  download-or-bust \"$${mounter_tar_sha}\" \"https://storage.googleapis.com/kubernetes-release/gci-mounter/mounter.tar\"\n  cp \"$${KUBE_HOME}/kubernetes/server/bin/mounter\" \"$${CONTAINERIZED_MOUNTER_HOME}/mounter\"\n  chmod a+x \"$${CONTAINERIZED_MOUNTER_HOME}/mounter\"\n  mv \"$${KUBE_HOME}/mounter.tar\" /tmp/mounter.tar\n  tar xf /tmp/mounter.tar -C \"$${CONTAINERIZED_MOUNTER_HOME}/rootfs\"\n  rm /tmp/mounter.tar\n  mkdir -p \"$${CONTAINERIZED_MOUNTER_HOME}/rootfs/var/lib/kubelet\"\n}\n\n# Install node problem detector binary.\nfunction install-node-problem-detector {\n  if [[ -n \"$${NODE_PROBLEM_DETECTOR_VERSION:-}\" ]]; then\n      local -r npd_version=\"$${NODE_PROBLEM_DETECTOR_VERSION}\"\n      local -r npd_sha1=\"$${NODE_PROBLEM_DETECTOR_TAR_HASH}\"\n  else\n      local -r npd_version=\"$${DEFAULT_NPD_VERSION}\"\n      local -r npd_sha1=\"$${DEFAULT_NPD_SHA1}\"\n  fi\n  local -r npd_tar=\"node-problem-detector-$${npd_version}.tar.gz\"\n\n  if is-preloaded \"$${npd_tar}\" \"$${npd_sha1}\"; then\n    echo \"node-problem-detector is preloaded.\"\n    return\n  fi\n\n  echo \"Downloading node problem detector.\"\n  local -r npd_release_path=\"https://storage.googleapis.com/kubernetes-release\"\n  download-or-bust \"$${npd_sha1}\" \"$${npd_release_path}/node-problem-detector/$${npd_tar}\"\n  local -r npd_dir=\"$${KUBE_HOME}/node-problem-detector\"\n  mkdir -p \"$${npd_dir}\"\n  tar xzf \"$${KUBE_HOME}/$${npd_tar}\" -C \"$${npd_dir}\" --overwrite\n  mv \"$${npd_dir}/bin\"/* \"$${KUBE_BIN}\"\n  chmod a+x \"$${KUBE_BIN}/node-problem-detector\"\n  rmdir \"$${npd_dir}/bin\"\n  rm -f \"$${KUBE_HOME}/$${npd_tar}\"\n}\n\nfunction install-cni-binaries {\n  local -r cni_tar=\"cni-plugins-amd64-$${DEFAULT_CNI_VERSION}.tgz\"\n  local -r cni_sha1=\"$${DEFAULT_CNI_SHA1}\"\n  if is-preloaded \"$${cni_tar}\" \"$${cni_sha1}\"; then\n    echo \"$${cni_tar} is preloaded.\"\n    return\n  fi\n\n  echo \"Downloading cni binaries\"\n  download-or-bust \"$${cni_sha1}\" \"https://storage.googleapis.com/kubernetes-release/network-plugins/$${cni_tar}\"\n  local -r cni_dir=\"$${KUBE_HOME}/cni\"\n  mkdir -p \"$${cni_dir}/bin\"\n  tar xzf \"$${KUBE_HOME}/$${cni_tar}\" -C \"$${cni_dir}/bin\" --overwrite\n  mv \"$${cni_dir}/bin\"/* \"$${KUBE_BIN}\"\n  rmdir \"$${cni_dir}/bin\"\n  rm -f \"$${KUBE_HOME}/$${cni_tar}\"\n}\n\n# Install crictl binary.\nfunction install-crictl {\n  if [[ -n \"$${CRICTL_VERSION:-}\" ]]; then\n    local -r crictl_version=\"$${CRICTL_VERSION}\"\n    local -r crictl_sha1=\"$${CRICTL_TAR_HASH}\"\n  else\n    local -r crictl_version=\"$${DEFAULT_CRICTL_VERSION}\"\n    local -r crictl_sha1=\"$${DEFAULT_CRICTL_SHA1}\"\n  fi\n  local -r crictl=\"crictl-$${crictl_version}-linux-amd64\"\n\n  # Create crictl config file.\n  cat > /etc/crictl.yaml <<EOF\nruntime-endpoint: $${CONTAINER_RUNTIME_ENDPOINT:-unix:///var/run/dockershim.sock}\nEOF\n\n  if is-preloaded \"$${crictl}\" \"$${crictl_sha1}\"; then\n    echo \"crictl is preloaded\"\n    return\n  fi\n\n  echo \"Downloading crictl\"\n  local -r crictl_path=\"https://storage.googleapis.com/kubernetes-release/crictl\"\n  download-or-bust \"$${crictl_sha1}\" \"$${crictl_path}/$${crictl}\"\n  mv \"$${KUBE_HOME}/$${crictl}\" \"$${KUBE_BIN}/crictl\"\n  chmod a+x \"$${KUBE_BIN}/crictl\"\n}\n\nfunction install-exec-auth-plugin {\n  if [[ ! \"$${EXEC_AUTH_PLUGIN_URL:-}\" ]]; then\n      return\n  fi\n  local -r plugin_url=\"$${EXEC_AUTH_PLUGIN_URL}\"\n  local -r plugin_sha1=\"$${EXEC_AUTH_PLUGIN_SHA1}\"\n\n  echo \"Downloading gke-exec-auth-plugin binary\"\n  download-or-bust \"$${plugin_sha1}\" \"$${plugin_url}\"\n  mv \"$${KUBE_HOME}/gke-exec-auth-plugin\" \"$${KUBE_BIN}/gke-exec-auth-plugin\"\n  chmod a+x \"$${KUBE_BIN}/gke-exec-auth-plugin\"\n\n  if [[ ! \"$${EXEC_AUTH_PLUGIN_LICENSE_URL:-}\" ]]; then\n      return\n  fi\n  local -r license_url=\"$${EXEC_AUTH_PLUGIN_LICENSE_URL}\"\n  echo \"Downloading gke-exec-auth-plugin license\"\n  download-or-bust \"\" \"$${license_url}\"\n  mv \"$${KUBE_HOME}/LICENSE\" \"$${KUBE_BIN}/gke-exec-auth-plugin-license\"\n}\n\nfunction install-kube-manifests {\n  # Put kube-system pods manifests in $${KUBE_HOME}/kube-manifests/.\n  local dst_dir=\"$${KUBE_HOME}/kube-manifests\"\n  mkdir -p \"$${dst_dir}\"\n  local -r manifests_tar_urls=( $(split-commas \"$${KUBE_MANIFESTS_TAR_URL}\") )\n  local -r manifests_tar=\"$${manifests_tar_urls[0]##*/}\"\n  if [ -n \"$${KUBE_MANIFESTS_TAR_HASH:-}\" ]; then\n    local -r manifests_tar_hash=\"$${KUBE_MANIFESTS_TAR_HASH}\"\n  else\n    echo \"Downloading k8s manifests sha1 (not found in env)\"\n    download-or-bust \"\" \"$${manifests_tar_urls[@]/.tar.gz/.tar.gz.sha1}\"\n    local -r manifests_tar_hash=$(cat \"$${manifests_tar}.sha1\")\n  fi\n\n  if is-preloaded \"$${manifests_tar}\" \"$${manifests_tar_hash}\"; then\n    echo \"$${manifests_tar} is preloaded.\"\n    return\n  fi\n\n  echo \"Downloading k8s manifests tar\"\n  download-or-bust \"$${manifests_tar_hash}\" \"$${manifests_tar_urls[@]}\"\n  tar xzf \"$${KUBE_HOME}/$${manifests_tar}\" -C \"$${dst_dir}\" --overwrite\n  local -r kube_addon_registry=\"$${KUBE_ADDON_REGISTRY:-k8s.gcr.io}\"\n  if [[ \"$${kube_addon_registry}\" != \"k8s.gcr.io\" ]]; then\n    find \"$${dst_dir}\" -name \\*.yaml -or -name \\*.yaml.in | \\\n      xargs sed -ri \"s@(image:\\s.*)k8s.gcr.io@\\1$${kube_addon_registry}@\"\n    find \"$${dst_dir}\" -name \\*.manifest -or -name \\*.json | \\\n      xargs sed -ri \"s@(image\\\":\\s+\\\")k8s.gcr.io@\\1$${kube_addon_registry}@\"\n  fi\n  cp \"$${dst_dir}/kubernetes/gci-trusty/gci-configure-helper.sh\" \"$${KUBE_BIN}/configure-helper.sh\"\n  if [[ -e \"$${dst_dir}/kubernetes/gci-trusty/gke-internal-configure-helper.sh\" ]]; then\n    cp \"$${dst_dir}/kubernetes/gci-trusty/gke-internal-configure-helper.sh\" \"$${KUBE_BIN}/\"\n  fi\n\n  cp \"$${dst_dir}/kubernetes/gci-trusty/health-monitor.sh\" \"$${KUBE_BIN}/health-monitor.sh\"\n\n  rm -f \"$${KUBE_HOME}/$${manifests_tar}\"\n  rm -f \"$${KUBE_HOME}/$${manifests_tar}.sha1\"\n}\n\n# A helper function for loading a docker image. It keeps trying up to 5 times.\n#\n# $1: Full path of the docker image\nfunction try-load-docker-image {\n  local -r img=$1\n  echo \"Try to load docker image file $${img}\"\n  # Temporarily turn off errexit, because we don't want to exit on first failure.\n  set +e\n  local -r max_attempts=5\n  local -i attempt_num=1\n  until timeout 30 $${LOAD_IMAGE_COMMAND:-docker load -i} \"$${img}\"; do\n    if [[ \"$${attempt_num}\" == \"$${max_attempts}\" ]]; then\n      echo \"Fail to load docker image file $${img} after $${max_attempts} retries. Exit!!\"\n      exit 1\n    else\n      attempt_num=$((attempt_num+1))\n      sleep 5\n    fi\n  done\n  # Re-enable errexit.\n  set -e\n}\n\n# Loads kube-system docker images. It is better to do it before starting kubelet,\n# as kubelet will restart docker daemon, which may interfere with loading images.\nfunction load-docker-images {\n  echo \"Start loading kube-system docker images\"\n  local -r img_dir=\"$${KUBE_HOME}/kube-docker-files\"\n  if [[ \"$${KUBERNETES_MASTER:-}\" == \"true\" ]]; then\n    try-load-docker-image \"$${img_dir}/kube-apiserver.tar\"\n    try-load-docker-image \"$${img_dir}/kube-controller-manager.tar\"\n    try-load-docker-image \"$${img_dir}/kube-scheduler.tar\"\n  else\n    try-load-docker-image \"$${img_dir}/kube-proxy.tar\"\n  fi\n}\n\n# Downloads kubernetes binaries and kube-system manifest tarball, unpacks them,\n# and places them into suitable directories. Files are placed in /home/kubernetes.\nfunction install-kube-binary-config {\n  cd \"$${KUBE_HOME}\"\n  local -r server_binary_tar_urls=( $(split-commas \"$${SERVER_BINARY_TAR_URL}\") )\n  local -r server_binary_tar=\"$${server_binary_tar_urls[0]##*/}\"\n  if [[ -n \"$${SERVER_BINARY_TAR_HASH:-}\" ]]; then\n    local -r server_binary_tar_hash=\"$${SERVER_BINARY_TAR_HASH}\"\n  else\n    echo \"Downloading binary release sha1 (not found in env)\"\n    download-or-bust \"\" \"$${server_binary_tar_urls[@]/.tar.gz/.tar.gz.sha1}\"\n    local -r server_binary_tar_hash=$(cat \"$${server_binary_tar}.sha1\")\n  fi\n\n  if is-preloaded \"$${server_binary_tar}\" \"$${server_binary_tar_hash}\"; then\n    echo \"$${server_binary_tar} is preloaded.\"\n  else\n    echo \"Downloading binary release tar\"\n    download-or-bust \"$${server_binary_tar_hash}\" \"$${server_binary_tar_urls[@]}\"\n    tar xzf \"$${KUBE_HOME}/$${server_binary_tar}\" -C \"$${KUBE_HOME}\" --overwrite\n    # Copy docker_tag and image files to $${KUBE_HOME}/kube-docker-files.\n    local -r src_dir=\"$${KUBE_HOME}/kubernetes/server/bin\"\n    local dst_dir=\"$${KUBE_HOME}/kube-docker-files\"\n    mkdir -p \"$${dst_dir}\"\n    cp \"$${src_dir}/\"*.docker_tag \"$${dst_dir}\"\n    if [[ \"$${KUBERNETES_MASTER:-}\" == \"false\" ]]; then\n      cp \"$${src_dir}/kube-proxy.tar\" \"$${dst_dir}\"\n    else\n      cp \"$${src_dir}/kube-apiserver.tar\" \"$${dst_dir}\"\n      cp \"$${src_dir}/kube-controller-manager.tar\" \"$${dst_dir}\"\n      cp \"$${src_dir}/kube-scheduler.tar\" \"$${dst_dir}\"\n      cp -r \"$${KUBE_HOME}/kubernetes/addons\" \"$${dst_dir}\"\n    fi\n    load-docker-images\n    mv \"$${src_dir}/kubelet\" \"$${KUBE_BIN}\"\n    mv \"$${src_dir}/kubectl\" \"$${KUBE_BIN}\"\n\n    mv \"$${KUBE_HOME}/kubernetes/LICENSES\" \"$${KUBE_HOME}\"\n    mv \"$${KUBE_HOME}/kubernetes/kubernetes-src.tar.gz\" \"$${KUBE_HOME}\"\n  fi\n\n  if [[ \"$${KUBERNETES_MASTER:-}\" == \"false\" ]] && \\\n     [[ \"$${ENABLE_NODE_PROBLEM_DETECTOR:-}\" == \"standalone\" ]]; then\n    install-node-problem-detector\n  fi\n\n  if [[ \"$${NETWORK_PROVIDER:-}\" == \"kubenet\" ]] || \\\n     [[ \"$${NETWORK_PROVIDER:-}\" == \"cni\" ]]; then\n    install-cni-binaries\n  fi\n\n  # Put kube-system pods manifests in $${KUBE_HOME}/kube-manifests/.\n  install-kube-manifests\n  chmod -R 755 \"$${KUBE_BIN}\"\n\n  # Install gci mounter related artifacts to allow mounting storage volumes in GCI\n  install-gci-mounter-tools\n\n  # Remount the Flexvolume directory with the \"exec\" option, if needed.\n  if [[ \"$${REMOUNT_VOLUME_PLUGIN_DIR:-}\" == \"true\" && -n \"$${VOLUME_PLUGIN_DIR:-}\" ]]; then\n    remount-flexvolume-directory \"$${VOLUME_PLUGIN_DIR}\"\n  fi\n\n  # Install crictl on each node.\n  install-crictl\n\n  if [[ \"$${KUBERNETES_MASTER:-}\" == \"false\" ]]; then\n    # TODO(awly): include the binary and license in the OS image.\n    install-exec-auth-plugin\n  fi\n\n  # Clean up.\n  rm -rf \"$${KUBE_HOME}/kubernetes\"\n  rm -f \"$${KUBE_HOME}/$${server_binary_tar}\"\n  rm -f \"$${KUBE_HOME}/$${server_binary_tar}.sha1\"\n}\n\n######### Main Function ##########\necho \"Start to install kubernetes files\"\n# if install fails, message-of-the-day (motd) will warn at login shell\nset-broken-motd\n\nKUBE_HOME=\"/home/kubernetes\"\nKUBE_BIN=\"$${KUBE_HOME}/bin\"\n\n# download and source kube-env\ndownload-kube-env\nsource \"$${KUBE_HOME}/kube-env\"\n\ndownload-kubelet-config \"$${KUBE_HOME}/kubelet-config.yaml\"\n\n# master certs\nif [[ \"$${KUBERNETES_MASTER:-}\" == \"true\" ]]; then\n  download-kube-master-certs\nfi\n\n# binaries and kube-system manifests\ninstall-kube-binary-config\n\necho \"Done for installing kubernetes files\"\n"
        },
    {
      key = "kube-labels"
      value = "beta.kubernetes.io/fluentd-ds-ready=true,cloud.google.com/gke-nodepool=pool-with-taints,cloud.google.com/gke-os-distribution=cos,stas1=stas1,stas2=stas2"
    },
    {
      key = "google-compute-enable-pcid"
      value = "true"
    },
    {
      key = "user-data"
      value = "#cloud-config\n\nwrite_files:\n  - path: /etc/systemd/system/kube-node-installation.service\n    permissions: 0644\n    owner: root\n    content: |\n      [Unit]\n      Description=Download and install k8s binaries and configurations\n      After=network-online.target\n\n      [Service]\n      Type=oneshot\n      RemainAfterExit=yes\n      ExecStartPre=/bin/mkdir -p /home/kubernetes/bin\n      ExecStartPre=/bin/mount --bind /home/kubernetes/bin /home/kubernetes/bin\n      ExecStartPre=/bin/mount -o remount,exec /home/kubernetes/bin\n      # Use --retry-connrefused opt only if it's supported by curl.\n      ExecStartPre=/bin/bash -c 'OPT=\"\"; if curl --help | grep -q -- \"--retry-connrefused\"; then OPT=\"--retry-connrefused\"; fi; /usr/bin/curl --fail --retry 5 --retry-delay 3 $OPT --silent --show-error -H \"X-Google-Metadata-Request: True\" -o /home/kubernetes/bin/configure.sh http://metadata.google.internal/computeMetadata/v1/instance/attributes/configure-sh'\n      ExecStartPre=/bin/chmod 544 /home/kubernetes/bin/configure.sh\n      ExecStart=/home/kubernetes/bin/configure.sh\n\n      [Install]\n      WantedBy=kubernetes.target\n\n  - path: /etc/systemd/system/kube-node-configuration.service\n    permissions: 0644\n    owner: root\n    content: |\n      [Unit]\n      Description=Configure kubernetes node\n      After=kube-node-installation.service\n\n      [Service]\n      Type=oneshot\n      RemainAfterExit=yes\n      ExecStartPre=/bin/chmod 544 /home/kubernetes/bin/configure-helper.sh\n      ExecStart=/home/kubernetes/bin/configure-helper.sh\n\n      [Install]\n      WantedBy=kubernetes.target\n\n  - path: /etc/systemd/system/kube-container-runtime-monitor.service\n    permissions: 0644\n    owner: root\n    content: |\n      [Unit]\n      Description=Kubernetes health monitoring for container runtime\n      After=kube-node-configuration.service\n\n      [Service]\n      Restart=always\n      RestartSec=10\n      RemainAfterExit=yes\n      RemainAfterExit=yes\n      ExecStartPre=/bin/chmod 544 /home/kubernetes/bin/health-monitor.sh\n      ExecStart=/home/kubernetes/bin/health-monitor.sh container-runtime\n\n      [Install]\n      WantedBy=kubernetes.target\n\n  - path: /etc/systemd/system/kubelet-monitor.service\n    permissions: 0644\n    owner: root\n    content: |\n      [Unit]\n      Description=Kubernetes health monitoring for kubelet\n      After=kube-node-configuration.service\n\n      [Service]\n      Restart=always\n      RestartSec=10\n      RemainAfterExit=yes\n      RemainAfterExit=yes\n      ExecStartPre=/bin/chmod 544 /home/kubernetes/bin/health-monitor.sh\n      ExecStart=/home/kubernetes/bin/health-monitor.sh kubelet\n\n      [Install]\n      WantedBy=kubernetes.target\n\n  - path: /etc/systemd/system/kube-logrotate.timer\n    permissions: 0644\n    owner: root\n    content: |\n      [Unit]\n      Description=Hourly kube-logrotate invocation\n\n      [Timer]\n      OnCalendar=hourly\n\n      [Install]\n      WantedBy=kubernetes.target\n\n  - path: /etc/systemd/system/kube-logrotate.service\n    permissions: 0644\n    owner: root\n    content: |\n      [Unit]\n      Description=Kubernetes log rotation\n      After=kube-node-configuration.service\n\n      [Service]\n      Type=oneshot\n      ExecStart=-/usr/sbin/logrotate /etc/logrotate.conf\n\n      [Install]\n      WantedBy=kubernetes.target\n\n  - path: /etc/systemd/system/kubernetes.target\n    permissions: 0644\n    owner: root\n    content: |\n      [Unit]\n      Description=Kubernetes\n\n      [Install]\n      WantedBy=multi-user.target\n\nruncmd:\n - systemctl daemon-reload\n - systemctl enable kube-node-installation.service\n - systemctl enable kube-node-configuration.service\n - systemctl enable kube-container-runtime-monitor.service\n - systemctl enable kubelet-monitor.service\n - systemctl enable kube-logrotate.timer\n - systemctl enable kube-logrotate.service\n - systemctl enable kubernetes.target\n - systemctl start kubernetes.target\n"
    },
    {
      key = "kube-env"
      value = "ALLOCATE_NODE_CIDRS: \"true\"\nAPI_SERVER_TEST_LOG_LEVEL: --v=3\nAUTOSCALER_ENV_VARS: kube_reserved=cpu=60m,memory=960Mi,ephemeral-storage=41Gi;node_taints=stas=stas:NoSchedule,stas2=stas2:NoSchedule;node_labels=beta.kubernetes.io/fluentd-ds-ready=true,cloud.google.com/gke-nodepool=pool-with-taints,cloud.google.com/gke-os-distribution=cos,stas1=stas1,stas2=stas2\nCA_CERT: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURDekNDQWZPZ0F3SUJBZ0lRWENPT3pMRCsyZUV4UUVpU2lsMWI4ekFOQmdrcWhraUc5dzBCQVFzRkFEQXYKTVMwd0t3WURWUVFERXlSaE9XTTROVE0xTmkweE9EQTNMVFF5WVRVdFlUazVOeTFsTnpneU56RmtaRE5qTTJFdwpIaGNOTVRrd05EQTVNRGN6TmpVM1doY05NalF3TkRBM01EZ3pOalUzV2pBdk1TMHdLd1lEVlFRREV5UmhPV000Ck5UTTFOaTB4T0RBM0xUUXlZVFV0WVRrNU55MWxOemd5TnpGa1pETmpNMkV3Z2dFaU1BMEdDU3FHU0liM0RRRUIKQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUNYcnozNFZuMkRpRFdqdTlxVmo4TGlkMGwyMEJQY1FIelBpcmV6Q2U1YgowNWRHRTdvelg5MEg1d2xlVlIvMjRvV2JPRWlBc1ZIbEZrL0JpVUtSMk9IMTRxSjM3MXZjTjJKaS9uemt4TGIyCnZ4cW1yb2dLbTJ3THV1THZCY1ViMXVUaFRFVXc3azZGOWFiLzBOUkdBTk5lSVpwdTZLcEk2TUxIdGdIcUpqcU0KQ2tiWkovak5uelN4akNIeXRaUGg2SkVnQTF6SW9jRlg1NGZ5eUFYeURDcHZuWGYxMVFSQU5rb0ZaNnhJeWRGYwpxaE9weVJIbTNDVGdlYlYzWUs0d1YvV21yNVRPT0pNOUtqL2RqMS9vMi9telNoL0YreXM2Q0xYM0R0RlhwdGVSCm9hcXNXR3hmU3R5R2VmYXlOSHJIdnRNSThkZStjSjFBeE9uTE9MV2dWVU5sQWdNQkFBR2pJekFoTUE0R0ExVWQKRHdFQi93UUVBd0lDQkRBUEJnTlZIUk1CQWY4RUJUQURBUUgvTUEwR0NTcUdTSWIzRFFFQkN3VUFBNElCQVFDSgppZU5BL2c4RFI1WDlrK1FiVnlEbzN5UEl6K0NTSFcxUXNBaG82TW1HeXdab3ZEdXR6MW9nNmIyQ1VTV09DSWlwCkpXakxhVGJpVmNNUmdqQjJ3U1pSWmM5UzBTYklWcFU0UmhPSnltRWlLR0lac3VwNWFmcmV2S3lzQ3Fqb3NwQ2wKOVdXMHpFU0doTCtIQS9YdDJqY3dKMk05ZDI1R3VMR25jQUhiM09tRXMwaWdiRWthb0ZIRkw2WEJmTjlDcldxTwpyM21ERnFyTjA5ZThHTnBzRUFVVXIvcVE0VUg3cjAwa0R5TFRYdkdMeENMWlZsMEVhaURZV3A3NnBwY1A5ZWErCi9qUWlpZUFiZ0RvTDRmZTFUQUs4TVg1YVRyQ0lxT3NVcFZHYmFRaXErd28xSmxiUlBxS1AzdFVOaFNVQktNZUcKZUVkQWdMY2s1V3NGdHNFQlVWODAKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=\nCLUSTER_IP_RANGE: 10.32.0.0/14\nCLUSTER_NAME: gke-demo\nCREATE_BOOTSTRAP_KUBECONFIG: \"true\"\nDNS_DOMAIN: cluster.local\nDNS_SERVER_IP: 10.35.240.10\nDOCKER_REGISTRY_MIRROR_URL: https://mirror.gcr.io\nELASTICSEARCH_LOGGING_REPLICAS: \"1\"\nENABLE_CLUSTER_DNS: \"true\"\nENABLE_CLUSTER_LOGGING: \"false\"\nENABLE_CLUSTER_MONITORING: stackdriver\nENABLE_CLUSTER_REGISTRY: \"false\"\nENABLE_CLUSTER_UI: \"true\"\nENABLE_L7_LOADBALANCING: glbc\nENABLE_METRICS_SERVER: \"true\"\nENABLE_NODE_LOGGING: \"true\"\nENABLE_NODE_PROBLEM_DETECTOR: standalone\nENABLE_NODELOCAL_DNS: \"false\"\nENV_TIMESTAMP: \"2019-04-09T08:36:57+00:00\"\nEXTRA_DOCKER_OPTS: --insecure-registry 10.0.0.0/8\nFEATURE_GATES: DynamicKubeletConfig=false,ExperimentalCriticalPodAnnotation=true\nFLUENTD_CONTAINER_RUNTIME_SERVICE: containerd\nHPA_USE_REST_CLIENTS: \"true\"\nINSTANCE_PREFIX: gke-gke-demo-eeb90ac7\nKUBE_ADDON_REGISTRY: gcr.io/google-containers\nKUBE_MANIFESTS_TAR_HASH: 2e93c73d5f6fd4144931a40bc88ae32cad144993\nKUBE_MANIFESTS_TAR_URL: https://storage.googleapis.com/kubernetes-release-gke/release/v1.11.8-gke.6/kubernetes-manifests.tar.gz,https://storage.googleapis.com/kubernetes-release-gke-eu/release/v1.11.8-gke.6/kubernetes-manifests.tar.gz,https://storage.googleapis.com/kubernetes-release-gke-asia/release/v1.11.8-gke.6/kubernetes-manifests.tar.gz\nKUBE_PROXY_TOKEN: Q-efYV9aL4Vuy66jy-9ZEvrYLkAbw29of4FXjHEhNEo=\nKUBELET_ARGS: --v=2 --cloud-provider=gce --experimental-mounter-path=/home/kubernetes/containerized_mounter/mounter\n  --experimental-check-node-capabilities-before-mount=true --cert-dir=/var/lib/kubelet/pki/\n  --cni-bin-dir=/home/kubernetes/bin --allow-privileged=true --kubeconfig=/var/lib/kubelet/kubeconfig\n  --experimental-kernel-memcg-notification=true --max-pods=110 --network-plugin=kubenet\n  --register-with-taints=stas=stas:NoSchedule,stas2=stas2:NoSchedule --node-labels=beta.kubernetes.io/fluentd-ds-ready=true,cloud.google.com/gke-nodepool=pool-with-taints,cloud.google.com/gke-os-distribution=cos,stas1=stas1,stas2=stas2\n  --volume-plugin-dir=/home/kubernetes/flexvolume --registry-qps=10 --registry-burst=20\n  --bootstrap-kubeconfig=/var/lib/kubelet/bootstrap-kubeconfig --node-status-max-images=25\nKUBELET_CERT: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMyekNDQWNPZ0F3SUJBZ0lRQW50N1VWZ1VPR2Y0eVNkWXNZSTZlakFOQmdrcWhraUc5dzBCQVFzRkFEQXYKTVMwd0t3WURWUVFERXlSaE9XTTROVE0xTmkweE9EQTNMVFF5WVRVdFlUazVOeTFsTnpneU56RmtaRE5qTTJFdwpIaGNOTVRrd05EQTVNRGd6TmpVNFdoY05NalF3TkRBM01EZ3pOalU0V2pBU01SQXdEZ1lEVlFRREV3ZHJkV0psCmJHVjBNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUZBQU9DQVE4QU1JSUJDZ0tDQVFFQXg3Qi95KzFSaUxBeW1uSFIKSFRKS0RuRXEycUk3cmY5SE53c01LOEVqZTdubXdpeW9Qc0x1RWFwaHZQQnRIcmh5Wmx0akV4OE1MUVYzYWdZRwpiSkdwNS9HbjRwSFZxZzVBcEZWak40S3YyQ2JqNkdOZlpTYmgvelFVMXBFUEZVVXN4c1hITHJTVG1TMzBIRUZCCjhsL3RxY3hKZ0xxb3dld2lieWJaMzllVDVXdDMxaXRRYXVWVFU4KzlkSnl6SG9rczM5SUJjTmo3UjBEMGdWbjcKa1NFTWdiRVErTTNuUnN3bHB2eURKdVJ0dXJVZmFDQmRFRVJUWjE0RG5nUVhKcE9WYkRwaEF0RHo5eVJpS2dpVApRRDIwR2lVbEE2YnRUM0tqODdPVHpUbklGNG9LeHE5TjQrVW5ZVlAzWFJUcTlKR3F4Q0NWU2haM1N1UUh3bFI0CkQ2VXR1UUlEQVFBQm94QXdEakFNQmdOVkhSTUJBZjhFQWpBQU1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQk4KbWRkMFZIRWhhOXhackFKMktndFZXczU2WEptMVIySWhUSEI3dUo3dGh5MU9jeDcrcmJOa0I5MEM1TXJXU3o2SwpNK21aTGcvMldNYkwyeDdaUmY4UEx5ZnN5eTROZXYvQ0JuZEk4WjV2UVNSaEhDdDZ3M1BzQVRkbTlVMkwxeVI1ClJpNm9pUVQzVUNYZGswS0NySVI2QmZJTWhXUTZHMzNTbWFYWWdFYVNXaXNXYWc0S2Jza2o5ZXRqMWp2QnhheWMKTW9zSHFPazRNNFU1c1YzY3pJNEdTZEV2MmhpUE5mSlhiK2hUSVczZnlQdlRQaUIwZElNYk0wa0lNMWJpbkt6ZAozQWtXeENVUTVMdk5jdU1IZmgwME9qZnJJb2hmTENadU1lZld6SW5kN0NHaDhCNy92Q25HZ2xNNUR4NUV3aEZrCk1Gb2JNNVBwUFR3clAxa1JMUXFsCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K\nKUBELET_KEY: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcFFJQkFBS0NBUUVBeDdCL3krMVJpTEF5bW5IUkhUSktEbkVxMnFJN3JmOUhOd3NNSzhFamU3bm13aXlvClBzTHVFYXBodlBCdEhyaHlabHRqRXg4TUxRVjNhZ1lHYkpHcDUvR240cEhWcWc1QXBGVmpONEt2MkNiajZHTmYKWlNiaC96UVUxcEVQRlVVc3hzWEhMclNUbVMzMEhFRkI4bC90cWN4SmdMcW93ZXdpYnliWjM5ZVQ1V3QzMWl0UQphdVZUVTgrOWRKeXpIb2tzMzlJQmNOajdSMEQwZ1ZuN2tTRU1nYkVRK00zblJzd2xwdnlESnVSdHVyVWZhQ0JkCkVFUlRaMTREbmdRWEpwT1ZiRHBoQXREejl5UmlLZ2lUUUQyMEdpVWxBNmJ0VDNLajg3T1R6VG5JRjRvS3hxOU4KNCtVbllWUDNYUlRxOUpHcXhDQ1ZTaFozU3VRSHdsUjRENlV0dVFJREFRQUJBb0lCQUJhSWV0OUUzQkMzeXpvRQowbU5BUjcySjlScy9OOHRLVlZ1bmRqdmd1ek9NdG5hZVNlenRHNmFvS29mQ3ZKbDlHRUduR2M2d1QvUXJtLzQ5CmlFK0xmMWZ5TzY3VUpIOWdSTmlXWHhBR1FmZjY2WGhSY0ZRT2QyMlFEN0xub3dOVUx6bU4yMHhRcWFBZElLRG8KbHp1MXFmQ2hZZ0R4N3pXVXd3ejJYaHNGYlVXenI4aTAxUGRvbWhPZGV5bUhFcWpreFRmWm1DUFd1RjMyQjdCVgoxUktVSGlrdkpMT1lvdVAySzVUTmdjekpnVkIwTkN2Y01VMFNwY2RyaHZna0JHL2ZNZW53N0kyaGh1eGxYd3BUClIvUFhrYS9kekFEUWRjbThZdXIvdERDUUVvWGhRaFVSYU8vV0JnTk9yRERqZnp1S1d3eTFUYWlneC9rb255OU8KKzFKV1pJVUNnWUVBK1VXMFJ6MUV3bENYOEtzVitGS09qU3MrVFBoTVk4SVpabEIyYUlmblFpYWk5VVM4S1p2YQpzbTMvaERjdFFCOWljY251YlBDTnd5bXRIMUMrelVmK1lxT3RLcEZKMURYWFoyQkQxVDJPNnlEWnY3T1JESGx5CkszOFJjeitRd0k0WitvbFloRCtWa1kzQzJhSzlJb1M2ZDlMQWlwbUZhQUE2ZEtHeXBZK3daeTBDZ1lFQXpSUTIKYXViZU9tazlpV2ZBYVlBWHU1T1BIQ1JVMFNzTTdnN3BiWU8xOCtLcUk0a3EyT0cvaGNMSEJsRWdGdXpzUGlIZApaZXlqUjBIN1JSV3ErUWFXTE5EaDhBRkhyOVU2MDBpWDZaang1L01PTGpDN2lKTFcxRys3Rm9mOXlTWitQNzFwCnNETFkxQytTYWhDRDFDTFZIRGIzL1B2Y1BEd3B6em1FRGxMdCtEMENnWUVBODA3dlRjM203SWhBRm1EWVcvOHgKTjJmck1yUDExRFdrRnpNWXNLVmV2RG44Tzgwd29LaUpDanJGK21ibEd6N0hGMnhUOWkvREg2anhXNnl6NEttUwpDdlBhVmI5a3dlY2Y3cjZPMTNoenBOdjJ6dUJXQjBnUGdaZFJFQjRPaTNUb3RKd1ZNMWpoQkNiTDl5U2Eyak9WCjB0bDZxSTU3SWUxL0lWS25qbVMzZWEwQ2dZRUFtbkg2ZVkvZEZRaGsrN0pUU2lEWnZyNW1MTDkvMFBjbkNiSFoKUWt6TEh4MDVIUUlVYnJtMHp6dmRQM2loUGlLMzJDTVE1YzNOT2NFTFJ3QUdmdnppNUdWN2dwQzBPRXZSdllVUwpReTZZSUNNQUx2RXNpckpyY0JtbFFGYXlYbWJLOVoza2xubjBxZmdad0I4bjZQOUNsN2tlRWp4cnBFRjdDMEU1Cm5yLzl6OUVDZ1lFQWh5cldaUkwrRlV5NkY0TUpxWTZJWkNhUXI1em1zRU5WVVVxZVFwR3h5dkIrblZLZ2hIdXoKMER4RXlGbk5NZ0pmajkwZDVhdFVXZFN1UmpIeVgxbjRUSFBUMDkrWG5MY2doUmU4R2tnTE5xZExwd0l4anA1NwpBNzczR3NVK2I3eXJNa0lQbXdPSDl2SHoxN2tiS1JZZFJpa2MwcXNha0t3Y2NSOXBRTUNpUFpjPQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo=\nKUBERNETES_MASTER: \"false\"\nKUBERNETES_MASTER_NAME: 35.194.16.59\nLOGGING_DESTINATION: gcp\nMONITORING_FLAG_SET: \"false\"\nNETWORK_PROVIDER: kubenet\nNODE_LOCAL_SSDS_EXT: \"\"\nNODE_PROBLEM_DETECTOR_TOKEN: jL3DOLE8ddTYret5oDvXrUPB1LegguXRLLzemMJdyFY=\nNODE_TAINTS: stas=stas:NoSchedule,stas2=stas2:NoSchedule\nREMOUNT_VOLUME_PLUGIN_DIR: \"true\"\nREQUIRE_METADATA_KUBELET_CONFIG_FILE: \"true\"\nSALT_TAR_HASH: \"\"\nSALT_TAR_URL: https://storage.googleapis.com/kubernetes-release-gke/release/v1.11.8-gke.6/kubernetes-salt.tar.gz,https://storage.googleapis.com/kubernetes-release-gke-eu/release/v1.11.8-gke.6/kubernetes-salt.tar.gz,https://storage.googleapis.com/kubernetes-release-gke-asia/release/v1.11.8-gke.6/kubernetes-salt.tar.gz\nSERVER_BINARY_TAR_HASH: 004a4dabc7ae12ec9e82c0fc7302f5a0a684677b\nSERVER_BINARY_TAR_URL: https://storage.googleapis.com/kubernetes-release-gke/release/v1.11.8-gke.6/kubernetes-server-linux-amd64.tar.gz,https://storage.googleapis.com/kubernetes-release-gke-eu/release/v1.11.8-gke.6/kubernetes-server-linux-amd64.tar.gz,https://storage.googleapis.com/kubernetes-release-gke-asia/release/v1.11.8-gke.6/kubernetes-server-linux-amd64.tar.gz\nSERVICE_CLUSTER_IP_RANGE: 10.35.240.0/20\nVOLUME_PLUGIN_DIR: /home/kubernetes/flexvolume\nZONE: us-central1-a\n"
    },
    {
      key = "enable-oslogin"
      value = "false"
    },
    {
      key = "kubelet-config"
      value = "apiVersion: kubelet.config.k8s.io/v1beta1\nauthentication:\n  anonymous:\n    enabled: false\n  webhook:\n    enabled: false\n  x509:\n    clientCAFile: /etc/srv/kubernetes/pki/ca-certificates.crt\nauthorization:\n  mode: Webhook\ncgroupRoot: /\nclusterDNS:\n- 10.35.240.10\nclusterDomain: cluster.local\nenableDebuggingHandlers: true\nevictionHard:\n  memory.available: 100Mi\n  nodefs.available: 10%\n  nodefs.inodesFree: 5%\nfeatureGates:\n  DynamicKubeletConfig: false\n  ExperimentalCriticalPodAnnotation: true\nkind: KubeletConfiguration\nkubeReserved:\n  cpu: 60m\n  ephemeral-storage: 41Gi\n  memory: 960Mi\nreadOnlyPort: 10255\nstaticPodPath: /etc/kubernetes/manifests\n"
    },
    {
      key = "cluster-name"
      value = "gke-demo"
    },
    {
      key = "cluster-uid"
      value = "eeb90ac7f6eb5610acc68725ff256a5c0358a0fc8e17026b5c19cc4d50901f07"
    },
    {
      key = "cluster-location"
      value = "us-central1-a"
    }
  ]

  labels = [
    {
      key = "stas1"
      value = "stas1"
    },
    {
      key = "stas2"
      value = "stas2"
    }
  ]

  taints = [
    {
      key = "stas"
      value = "stas"
      effect = "NoSchedule"
    },
    {
      key = "stas2"
      value = "stas2"
      effect = "NoSchedule"
    }
  ]
}