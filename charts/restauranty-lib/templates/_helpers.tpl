{{/* Name of the service, taken from the calling chart */}}
{{- define "restauranty-lib.name" -}}
{{ .Chart.Name }}
{{- end }}

{{/* Labels used to find the pods (keep small: they cannot change later) */}}
{{- define "restauranty-lib.selectorLabels" -}}
app.kubernetes.io/name: {{ include "restauranty-lib.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* All labels: the selector labels plus descriptive ones */}}
{{- define "restauranty-lib.labels" -}}
{{ include "restauranty-lib.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/part-of: restauranty
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
