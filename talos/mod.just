set default-list
set default-script
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

topf_config := source_directory() / "topf.yaml"

[confirm('Apply Talos config to ' + node + ' [y|N] ?')]
[doc('Apply Talos config to a node')]
apply-node node *args:
    topf --topfconfig "{{ topf_config }}" apply --nodes-filter "^{{ node }}$" {{ args }}

[doc('Download Talos machine image')]
download-image version:
    export SCHEMATIC="$(just talos schematic-id)"
    curl -fL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors --progress-bar \
        -o "{{ source_directory() }}/talos-{{ version }}-${SCHEMATIC:0:8}.iso" \
        "https://factory.talos.dev/image/${SCHEMATIC}/{{ version }}/metal-amd64.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "${SCHEMATIC}"

[confirm('Reboot node ' + node + ' [y|N] ?')]
[doc('Reboot a node')]
reboot-node node:
    talosctl -n "{{ node }}" reboot -m powercycle

[doc('Render Talos config for a node')]
[script]
render-config node:
    out="$(mktemp -d)"
    trap 'rm -rf "$out"' EXIT
    topf --topfconfig "{{ topf_config }}" render --nodes-filter "^{{ node }}$" -o "$out" >/dev/null
    cat "$out/{{ node }}.yaml"

[confirm('Reset node ' + node + ' [y|N] ?')]
[doc('Reset a node')]
reset-node node *args:
    topf --topfconfig "{{ topf_config }}" reset --nodes-filter "^{{ node }}$" --full=false {{ args }}

[confirm('Shutdown node ' + node + ' [y|N] ?')]
[doc('Shutdown a node')]
shutdown-node node *args:
    talosctl -n "{{ node }}" shutdown --force {{ args }}

[confirm('Upgrade Kubernetes to ' + version + ' [y|N] ?')]
[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    talosctl -n "$(talosctl config info -o yaml | yq -r -e '.endpoints[0]')" upgrade-k8s --to "{{ version }}"

[confirm('Upgrade node ' + node + ' [y|N] ?')]
[doc('Upgrade Talos version on a node')]
upgrade-node node *args:
    topf --topfconfig "{{ topf_config }}" upgrade --nodes-filter "^{{ node }}$" --reboot-mode powercycle {{ args }}

[private]
schematic-id:
    topf --topfconfig "{{ topf_config }}" schematic-ids | head -1