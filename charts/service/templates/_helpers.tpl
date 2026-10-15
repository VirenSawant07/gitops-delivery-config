{{- define "service.selectorLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
{{- end }}

{{- define "service.labels" -}}
{{ include "service.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/part-of: gitops-delivery-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
