# Test targets
fmt:
	go fmt ./...

vet:
	go vet ./...

test: fmt vet
	go test ./... -coverprofile cover.out

# Build targets
build: fmt vet
	go build -o bin/manager main.go

run: fmt vet
	go run ./main.go

generate:
	controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."

manifests:
	controller-gen rbac:roleName=manager-role crd webhook paths="./..." output:crd:artifacts:config=config/crd/bases
