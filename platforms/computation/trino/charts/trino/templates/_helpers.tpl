{{/*
Return Nifi Namespace to use
*/}}
{{- define "nifi.namespace" -}}
{{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
{{- else -}}
    {{- .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Return the proper Nifi image name
*/}}
{{- define "nifi.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/*
Form the Nifi Registry URL and port.
If nifi-registry is installed as part of this chart, use k8s service discovery, else use user-provided name and port
*/}}
{{- define "nifi.registry.url" }}
{{- $port := .Values.registry.port | toString }}
{{- if .Values.registry.enabled -}}
{{- printf "http://%s-registry:%s" .Release.Name $port }}
{{- else -}}
{{- printf "http://%s:%s" .Values.registry.url $port }}
{{- end -}}
{{- end -}}

{{/*
 Create the name of the service account to use
 */}}
{{- define "nifi.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified zookeeper name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "nifi.zookeeper.fullname" -}}
{{- if .Values.zookeeper.fullnameOverride -}}
{{- .Values.zookeeper.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "zookeeper" .Values.zookeeper.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Returns the zookeeper.connect setting value
*/}}
{{- define "kafka.zookeeperConnect" -}}
{{- if .Values.zookeeper.enabled -}}
{{- printf "%s:%s%s" (include "nifi.zookeeper.fullname" .) (ternary "3181" "2181" .Values.tls.zookeeper.enabled) (tpl .Values.zookeeperChrootPath .) -}}
{{- else -}}
{{- printf "%s%s" (join "," .Values.externalZookeeper.servers) (tpl .Values.zookeeperChrootPath .) -}}
{{- end -}}
{{- end -}}
