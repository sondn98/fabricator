{{/*
Expand the name of the chart.
*/}}
{{- define "pgbouncer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "pgbouncer.fullname" -}}
{{- $name := default .Chart.Name .Values.fullnameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "pgbouncer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
Selector labels
*/}}
{{- define "pgbouncer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pgbouncer.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pgbouncer.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "pgbouncer.chart" . }}
{{- if .Values.labels }}
{{ toYaml .Values.labels }}
{{- end }}
{{ include "pgbouncer.selectorLabels" . }}
{{- end }}

{{/*
Get the users secret name.
*/}}
{{- define "pgbouncer.userlistSecretName" -}}
{{- if .Values.existingUserlistSecret -}}
{{- printf "%s" .Values.existingUserlistSecret -}}
{{- else -}}
{{- printf "%s-userlist" (include "pgbouncer.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "airflow.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.web.image .Values.scheduler.image .Values.worker.image .Values.git .Values.metrics.image) "global" .Values.global) -}}
{{- end -}}
