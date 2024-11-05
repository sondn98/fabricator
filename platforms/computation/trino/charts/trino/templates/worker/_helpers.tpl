{{/*
Return Trino worker configuration to use
*/}}
{{- define "trino.worker.config" -}}
{{- $workerConfig := mergeOverwrite .Values.config .Values.worker.config -}}
{{- $_ := set $workerConfig "coordinator" "false" }}
{{- $_ := set $workerConfig "discovery.uri" (printf "http://%s-discovery:8080" (include "common.names.fullname" .)-discovery) }}
{{- with $workerConfig }}
{{ toYaml . }}
{{- end }}
{{- end -}}
