package controller

import (
	"context"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	aiopsv1alpha1 "github.com/suhlabs/ai-ops-operator/api/v1alpha1"
)

// AIOpsAgentReconciler reconciles a AIOpsAgent object
type AIOpsAgentReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=aiops.corp.local,resources=aiopsagents,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=aiops.corp.local,resources=aiopsagents/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=core,resources=pods,verbs=get;list;watch

func (r *AIOpsAgentReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// Fetch the AIOpsAgent instance
	agent := &aiopsv1alpha1.AIOpsAgent{}
	err := r.Get(ctx, req.NamespacedName, agent)
	if err != nil {
		if errors.IsNotFound(err) {
			logger.Info("AIOpsAgent resource not found. Ignoring since object must be deleted")
			return ctrl.Result{}, nil
		}
		logger.Error(err, "Failed to get AIOpsAgent")
		return ctrl.Result{}, err
	}

	// Define a new Deployment using Vault Agent Injector annotations
	dep := r.deploymentForAIOpsAgent(agent)

	// Set AIOpsAgent instance as the owner and controller
	if err := controllerutil.SetControllerReference(agent, dep, r.Scheme); err != nil {
		return ctrl.Result{}, err
	}

	// Check if the deployment already exists
	found := &appsv1.Deployment{}
	err = r.Get(ctx, client.ObjectKey{Name: dep.Name, Namespace: dep.Namespace}, found)
	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating a new Deployment", "Deployment.Namespace", dep.Namespace, "Deployment.Name", dep.Name)
		err = r.Create(ctx, dep)
		if err != nil {
			logger.Error(err, "Failed to create new Deployment", "Deployment.Namespace", dep.Namespace, "Deployment.Name", dep.Name)
			return ctrl.Result{}, err
		}
		// Deployment created successfully - return and requeue
		return ctrl.Result{Requeue: true}, nil
	} else if err != nil {
		logger.Error(err, "Failed to get Deployment")
		return ctrl.Result{}, err
	}

	// Update the AIOpsAgent status
	// (In a real scenario, we'd check if the pods are actually ready before setting this)
	agent.Status.ReplicasReady = found.Status.ReadyReplicas
	
	// Add "Ready" condition
	readyCondition := metav1.Condition{
		Type:               "Ready",
		Status:             metav1.ConditionTrue,
		Reason:             "DeploymentCreated",
		Message:            "The AIOpsAgent deployment has been created and reconciled",
		LastTransitionTime: metav1.Now(),
	}
	
	setCondition(&agent.Status.Conditions, readyCondition)
	
	err = r.Status().Update(ctx, agent)
	if err != nil {
		logger.Error(err, "Failed to update AIOpsAgent status")
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

// deploymentForAIOpsAgent returns a ai-ops-agent Deployment object
func (r *AIOpsAgentReconciler) deploymentForAIOpsAgent(agent *aiopsv1alpha1.AIOpsAgent) *appsv1.Deployment {
	labels := map[string]string{"app": agent.Name}
	replicas := agent.Spec.Replicas
	
	// Inject Vault Agent annotations for seamless secrets
	annotations := map[string]string{
		"vault.hashicorp.com/agent-inject": "true",
		"vault.hashicorp.com/role": "ai-ops-agent",
	}

	if agent.Spec.VaultSecretPath != "" {
		annotations["vault.hashicorp.com/agent-inject-secret-config"] = agent.Spec.VaultSecretPath
	}

	dep := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      agent.Name,
			Namespace: agent.Namespace,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: &replicas,
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: labels,
					Annotations: annotations,
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{{
						Image: agent.Spec.Image,
						Name:  "aiopsagent",
						Ports: []corev1.ContainerPort{{
							ContainerPort: 8000,
							Name:          "http",
						}},
					}},
				},
			},
		},
	}
	return dep
}

func setCondition(conditions *[]metav1.Condition, newCondition metav1.Condition) {
	for i, c := range *conditions {
		if c.Type == newCondition.Type {
			if c.Status != newCondition.Status {
				(*conditions)[i] = newCondition
			}
			return
		}
	}
	*conditions = append(*conditions, newCondition)
}

func (r *AIOpsAgentReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&aiopsv1alpha1.AIOpsAgent{}).
		Owns(&appsv1.Deployment{}).
		Complete(r)
}
