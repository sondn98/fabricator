{{/*
Return Trino worker configuration to use
*/}}
{{- define "trino.coordinator.config" -}}
{{- $coordinatorConfig := mergeOverwrite .Values.config .Values.coordinator.config -}}
{{- $_ := set $coordinatorConfig "coordinator" "true" }}
{{- $_ := set $coordinatorConfig "discovery.uri" (printf "http://%s-discovery:8080" (include "common.names.fullname" .)-discovery) }}
{{- with $coordinatorConfig }}
{{ toYaml . }}
{{- end }}
{{- end -}}
