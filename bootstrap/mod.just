set default-list
set default-script
set no-exit-message
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

topf_config := justfile_dir() / "talos" / "topf.yaml"

[confirm('Bootstrap cluster? [y|N]')]
[doc('Bootstrap a Talos & Kubernetes cluster end-to-end')]
cluster: apply credentials (kubeconfig "node") base apps kubeconfig

[private]
apply:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    if ! topf --topfconfig "{{ topf_config }}" apply --auto-bootstrap; then
        just log fatal "Failed to apply Talos configuration / bootstrap" "stage" "{{ recipe_name() }}"
    fi

[private]
credentials:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    if ! topf --topfconfig "{{ topf_config }}" talosconfig > "{{ justfile_dir() }}/talosconfig"; then
        just log fatal "Failed to fetch talosconfig" "stage" "{{ recipe_name() }}"
    fi

[private]
kubeconfig lb="cilium":
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    if ! topf --topfconfig "{{ topf_config }}" kubeconfig --validity 720h > "{{ justfile_dir() }}/kubeconfig"; then
        just log fatal "Failed to fetch kubeconfig" "stage" "{{ recipe_name() }}"
    fi
    if [[ "{{ lb }}" != "cilium" ]]; then
        controller="$(yq -r -e '.nodes[] | select(.role == "control-plane") | (.ip // .host)' "{{ topf_config }}" | head -1)"
        cluster_name="$(kubectl --kubeconfig "{{ justfile_dir() }}/kubeconfig" config view -o jsonpath='{.clusters[0].name}')"
        if ! kubectl --kubeconfig "{{ justfile_dir() }}/kubeconfig" config set-cluster "$cluster_name" --server "https://${controller}:6443"; then
            just log fatal "Failed to set kubectl cluster server address" "stage" "{{ recipe_name() }}"
        fi
    fi

[private]
base: ready
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    if ! kubectl kustomize {{ source_directory() }}/kustomize/apps | vals eval -f - | kubectl apply --server-side --force-conflicts -f -; then
        just log fatal "Failed to apply base manifests" "stage" "{{ recipe_name() }}"
    fi
    if ! helmfile -f "{{ source_directory() }}/helmfile/crds.yaml" template -q | yq ea -r -e 'select(.kind == "CustomResourceDefinition")' | kubectl apply --server-side --force-conflicts -f -; then
        just log fatal "Failed to apply base crds" "stage" "{{ recipe_name() }}"
    fi

[private]
apps:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    if ! helmfile -f "{{ source_directory() }}/helmfile/apps.yaml" sync --hide-notes; then
        just log fatal "Failed to sync helmfile" "stage" "{{ recipe_name() }}"
    fi

# Wait until nodes register as Ready=False. They only become Ready=True once the CNI is healthy.
[private]
ready:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    if ! kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
            just log info "Nodes not available, waiting for nodes to be available. Retrying in 5 seconds..." "stage" "{{ recipe_name() }}"
            sleep 5
        done
    fi