package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// AIOpsAgentSpec defines the desired state of AIOpsAgent
type AIOpsAgentSpec struct {
	// Replicas defines the desired number of agent instances
	Replicas int32 `json:"replicas,omitempty"`

	// Image defines the agent container image
	Image string `json:"image,omitempty"`

	// VaultSecretPath defines the path in Vault to inject secrets from
	VaultSecretPath string `json:"vaultSecretPath,omitempty"`
}

// AIOpsAgentStatus defines the observed state of AIOpsAgent
type AIOpsAgentStatus struct {
	// Conditions hold the latest available observations of the agent's state
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// ReplicasReady shows how many replicas are successfully running
	ReplicasReady int32 `json:"replicasReady,omitempty"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:printcolumn:name="Replicas",type="integer",JSONPath=".spec.replicas"
//+kubebuilder:printcolumn:name="Ready",type="integer",JSONPath=".status.replicasReady"
//+kubebuilder:printcolumn:name="Status",type="string",JSONPath=".status.conditions[?(@.type==\"Ready\")].status"

// AIOpsAgent is the Schema for the aiopsagents API
type AIOpsAgent struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   AIOpsAgentSpec   `json:"spec,omitempty"`
	Status AIOpsAgentStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// AIOpsAgentList contains a list of AIOpsAgent
type AIOpsAgentList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []AIOpsAgent `json:"items"`
}

func init() {
	SchemeBuilder.Register(&AIOpsAgent{}, &AIOpsAgentList{})
}
