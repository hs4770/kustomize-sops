ARG GO_VERSION="1.19"

#--------------------------------------------#
#--------Build KSOPS and Kustomize-----------#
#--------------------------------------------#

# Stage 1: Build KSOPS and Kustomize
FROM registry.access.redhat.com/ubi8/go-toolset:${GO_VERSION}-8 AS builder

ARG TARGETPLATFORM
ARG PKG_NAME=ksops

# Match Argo CD's build
ENV GO111MODULE=on

# Define kustomize config location
ENV XDG_CONFIG_HOME=$HOME/.config

# Export templated Go env variables
RUN export GOOS=$(echo ${TARGETPLATFORM} | cut -d / -f1) && \
    export GOARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) && \
    export GOARM=$(echo ${TARGETPLATFORM} | cut -d / -f3 | cut -c2-)

WORKDIR /go/src/github.com/viaduct-ai/kustomize-sops

COPY . .
RUN go mod download
RUN make install
RUN make kustomize

# # Stage 2: Final image
FROM registry.access.redhat.com/ubi9/ubi-minimal

LABEL org.opencontainers.image.source="https://github.com/viaduct-ai/kustomize-sops"

# ca-certs and git could be required if kustomize remote-refs are used
RUN microdnf install -y git ca-certificates && \
    microdnf clean all

# Copy only necessary files from the builder stage
COPY --from=builder /go/bin/ksops /usr/local/bin/ksops
COPY --from=builder /go/bin/kustomize /usr/local/bin/kustomize
COPY --from=builder /go/bin/kustomize-sops /usr/local/bin/kustomize-sops

# Create a symlink from /usr/local/bin/ksops to /go/bin/ksops to preserve backwards compatibility (this will be removed in a future release)
RUN mkdir -p /go/bin
RUN ln -s /usr/local/bin/ksops /go/bin/ksops
RUN ln -s /usr/local/bin/kustomize /go/bin/kustomize
RUN ln -s /usr/local/bin/kustomize-sops /go/bin/kustomize-sops
# Set GOPATH to /go to preserve backwards compatibility (this will be removed in a future release)
ENV GOPATH=/go

# Change working directory to /usr/local/bin
WORKDIR /usr/local/bin

CMD ["kustomize", "version"]
