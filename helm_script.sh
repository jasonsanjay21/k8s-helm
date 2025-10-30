#!/bin/bash

# Create the Helm chart directory structure
mkdir -p tiny-http-app/templates

# Create Chart.yaml
cat > tiny-http-app/Chart.yaml <<EOF
apiVersion: v2
name: tiny-http-app
description: A Helm chart for tiny-http-app
type: application
version: 0.1.0
appVersion: "latest"
EOF

# Create values.yaml
cat > tiny-http-app/values.yaml <<EOF
replicaCount: 2

image:
  repository: jasonsanjay/tiny-http-app
  pullPolicy: IfNotPresent
  tag: "latest"

nameOverride: ""
fullnameOverride: ""

service:
  type: NodePort
  port: 8080
  targetPort: 8080
  nodePort: 30080

env:
  appMessage: "Hello from Kubernetes"

resources: {}
  # limits:
  #   cpu: 100m
  #   memory: 128Mi
  # requests:
  #   cpu: 100m
  #   memory: 128Mi

nodeSelector: {}

tolerations: []

affinity: {}
EOF

# Create templates/_helpers.tpl
cat > tiny-http-app/templates/_helpers.tpl <<'EOF'
{{/*
Expand the name of the chart.
*/}}
{{- define "tiny-http-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "tiny-http-app.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tiny-http-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tiny-http-app.labels" -}}
helm.sh/chart: {{ include "tiny-http-app.chart" . }}
{{ include "tiny-http-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tiny-http-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tiny-http-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
EOF

# Create templates/deployment.yaml
cat > tiny-http-app/templates/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "tiny-http-app.fullname" . }}
  labels:
    {{- include "tiny-http-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "tiny-http-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "tiny-http-app.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
        env:
        - name: APP_MESSAGE
          value: {{ .Values.env.appMessage | quote }}
        {{- with .Values.resources }}
        resources:
          {{- toYaml . | nindent 10 }}
        {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
EOF

# Create templates/service.yaml
cat > tiny-http-app/templates/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "tiny-http-app.fullname" . }}
  labels:
    {{- include "tiny-http-app.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      {{- if and (eq .Values.service.type "NodePort") .Values.service.nodePort }}
      nodePort: {{ .Values.service.nodePort }}
      {{- end }}
  selector:
    {{- include "tiny-http-app.selectorLabels" . | nindent 4 }}
EOF

echo "Helm chart structure created successfully!"
echo ""
echo "Directory structure:"
tree tiny-http-app/ || find tiny-http-app/ -type f

echo ""
echo "To validate the chart, run:"
echo "  helm lint tiny-http-app/"
echo ""
echo "To test template rendering, run:"
echo "  helm template tiny-http-app tiny-http-app/"
echo ""
echo "To install the chart, run:"
echo "  helm install tiny-http-app tiny-http-app/"
echo ""
echo "To upgrade the release, run:"
echo "  helm upgrade tiny-http-app tiny-http-app/"
echo ""
echo "To uninstall the release, run:"
echo "  helm uninstall tiny-http-app"
