{{/*
Return Trino Namespace to use
*/}}
{{- define "trino.namespace" -}}
{{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
{{- else -}}
    {{- .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Return the proper Trino image name
*/}}
{{- define "trino.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/*
 Create the name of the service account to use
 */}}
{{- define "trino.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Return Trino common configuration to use
*/}}
{{- define "trino.config" -}}
{{- $config := .Values.config }}
{{- if .Values.tls.client.enabled }}
  {{- $_ := set $config "http-server.http.enabled" "false" }}
  {{- $_ := set $config "http-server.https.enabled" "true" }}
  {{- $_ := set $config "http-server.https.port" .Values.service.port.https }}
  {{- $_ := set $config "http-server.https.keystore.path" .Values.tls.client.keystorePath }}
  {{- $_ := set $config "http-server.https.keystore.key" .Values.tls.client.keystorePassword }}
  {{- $_ := set $config "http-server.https.truststore.path .Values.tls.client.truststorePath }}
  {{- $_ := set $config "http-server.https.truststore.key" .Values.tls.client.truststorePassword  }}
{{- else }}
  {{- $_ := set $config "http-server.http.enabled" "true" }}
  {{- $_ := set $config "http-server.http.port" .Values.service.port.http }}
{{- end }}
{{- if .Values.faultTolerant.enabled }}
  {{- $_ := set $config "retry-policy" .Values.faultTolerant.policy }}
{{- end -}}
{{- end -}}

{{/*
Return Trino exchange manager configuration
*/}}
{{- define "trino.exchangeManager" -}}
{{- $exchangeConfig := dict -}}
{{- if .Values.faultTolerant.enabled }}
  {{- $_ := set $exchangeConfig "exchange-manager.name" .Values.faultTolerant.exchangeManager.name }}
{{- end -}}
{{- end -}}
