# Janky front-end to bring some sanity (?) to the litany of tools and switches
# for working with a k8s cluster. This file adds a set of monitoring and
# observability tool including: Prometheus, Grafana and Kiali by way of installing
# them using Helm. Note the Helm repo is up-to-date as of mid-Nov 2020. 
#
# Prometheus, Grafana and Kiali are installed into the same namespace (istio-system)
# to make them work out-of-the-box (install). It may be possible to separate each of
# them out into their own namespace but I didn't have time to validate/explore this.
#
# The intended approach to working with this makefile is to update select
# elements (body, id, IP, port, etc) as you progress through your workflow.
# Where possible, stodout outputs are tee into .out files for later review.
#

KC=kubectl
DK=docker
HELM=helm

# these might need to change
APP_NS=c756ns
ISTIO_NS=istio-system
KIALI_OP_NS=kiali-operator

RELEASE=c756

# This might also change in step with Prometheus' evolution
PROMETHEUSPOD=prometheus-$(RELEASE)-kube-p-prometheus-0

all: install-prom install-kiali


# add the latest active repo for Prometheus
init-helm:
	$(HELM) repo add prometheus-community https://prometheus-community.github.io/helm-charts

# note that the name $(RELEASE) is discretionary; it is used to reference the install 
# Grafana is included within this Prometheus package
install-prom:
	echo $(HELM) install $(RELEASE) --namespace $(ISTIO_NS) prometheus-community/kube-prometheus-stack > obs-install-prometheus.log
	$(HELM) install $(RELEASE) -f helm-kube-stack-values.yaml --namespace $(ISTIO_NS) prometheus-community/kube-prometheus-stack | tee -a obs-install-prometheus.log

uninstall-prom:
	echo $(HELM) uninstall $(RELEASE) --namespace $(ISTIO_NS) > obs-uninstall-prometheus.log
	$(HELM) uninstall $(RELEASE) --namespace $(ISTIO_NS) | tee -a obs-uninstall-prometheus.log

install-kiali:
	echo $(HELM) install --namespace $(ISTIO_NS) --set auth.strategy="anonymous" --repo https://kiali.org/helm-charts kiali-server kiali-server > obs-kiali.log
	# This will fail every time after the first---the "|| true" suffix keeps Make running despite error
	$(KC) create namespace $(KIALI_OP_NS) || true  | tee -a obs-kiali.log
	$(HELM) install --set cr.create=true --set cr.namespace=$(ISTIO_NS) --namespace $(KIALI_OP_NS) --repo https://kiali.org/helm-charts kiali-operator kiali-operator | tee -a obs-kiali.log

update-kiali:
	$(KC) apply -n $(ISTIO_NS) -f kiali-cr.yaml | tee -a obs-kiali.log

uninstall-kiali:
	echo $(HELM) uninstall kiali-server --namespace $(ISTIO_NS) > obs-uninstall-kiali.log
	$(HELM) uninstall kiali-server --namespace $(ISTIO_NS) | tee -a obs-uninstall-kiali.log

promport:
	$(KC) describe pods $(PROMETHEUSPOD) -n $(ISTIO_NS)

extern: showcontext
	$(KC) -n $(ISTIO_NS) get svc istio-ingressgateway

# show deploy and pods in current ns; svc of cmpt756 ns
ls: showcontext
	$(KC) get gw,deployments,pods
	$(KC) -n $(APP_NS) get svc
	$(HELM) list -n $(ISTIO_NS)


# reminder of current context
showcontext:
	$(KC) config get-contexts