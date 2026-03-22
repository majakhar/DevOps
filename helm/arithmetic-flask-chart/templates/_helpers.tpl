{{/* Common template helpers for arithmetic-flask chart */}}
{{- define "arithmetic-flask.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "arithmetic-flask.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "arithmetic-flask.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "arithmetic-flask.labels" -}}
app.kubernetes.io/name: {{ include "arithmetic-flask.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{- define "arithmetic-flask.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- printf "%s-%s" .Release.Name "sa" -}}
{{- else -}}
{{- default .Values.serviceAccount.name "" -}}
{{- end -}}
{{- end -}}
