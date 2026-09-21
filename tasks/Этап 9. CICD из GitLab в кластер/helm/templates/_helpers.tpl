{{- define "devops-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "devops-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "devops-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "devops-app.labels" -}}
helm.sh/chart: {{ include "devops-app.chart" . }}
app.kubernetes.io/name: {{ include "devops-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "devops-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "devops-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "devops-app.componentLabels" -}}
{{ include "devops-app.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "devops-app.databaseSecretName" -}}
{{- default (printf "%s-database" (include "devops-app.fullname" .)) .Values.postgresql.secret.existingSecret | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "devops-app.postgresqlName" -}}
{{- printf "%s-postgresql" (include "devops-app.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "devops-app.redisName" -}}
{{- printf "%s-redis" (include "devops-app.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "devops-app.configName" -}}
{{- printf "%s-config" (include "devops-app.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

