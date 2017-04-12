# BOSH Release for go-graphite

The aim of this bosh release is to deploy a go-graphite cluster consisting of the following components:

* [carbon-c-relay](https://github.com/grobian/carbon-c-relay) for metrics relaying and fordwarding
* [go-carbon](https://github.com/lomik/go-carbon) sever to storage metrics
* [carbonzipper](https://github.com/dgryski/carbonzipper) to transparently merge graphite carbon backends
* [carbonapi](https://github.com/dgryski/carbonapi) to provide the graphite API 
* [buckytools](https://github.com/jjneely/buckytools) to provide a management layer on top of go-carbon

## Requirements
We structured the release around the conceps of availability zones and clusters. One of the properties required by the `carbon-c-relay` job
gives you a way of configuring the architecture of your `go-graphite` metrics deployment.
`go-carbon` instances are assigned automatically to a specific cluster based on the `az` value of their vm instance. This is achieved by taking advantage of [bosh links](https://bosh.io/docs/links.html).

Let's discuss this idea more in details:
```
    properties:
      carbon-c-relay:
        clusters:
          - name: "cluster1"
            lb: "jump_fnv1a_ch"
            replication: 1
            azs: ["z1"]
          - name: "cluster2"
            lb: "jump_fnv1a_ch"
            replication: 1
            azs: ["z2"]
```
`clusters` is a list of dictionaries, each representing a carbon-c-relay cluster. The cluster instances are grouped by availability zone.

One cluster can be deployed across several `az`s, like in the following example:
```
    properties:
      carbon-c-relay:
        clusters:
          - name: "cluster1"
            lb: "jump_fnv1a_ch"
            replication: 1
            azs: ["z1", "z2"] #<- A cluster can use as many azs as we'd like
```

however you cannot define different clusters using the same availability zone. For example this is not allowed, and a validation error is going to be raised at deployment time. Because of this limitation it is also impossible to define more `carbon-c-relay` clusters than the number of configured azs.
So in a typical 3 azs architecture you can create maximum 3 different clusters each of them deployed to a different az.

###Example of erroneous configuration
```
    properties:
      carbon-c-relay:
        clusters:
          - name: "cluster1"
            lb: "jump_fnv1a_ch"
            replication: 1
            azs: ["z1", "z2"]
          - name: "cluster2"
            lb: "jump_fnv1a_ch"
            replication: 1
            azs: ["z2", "z3"]   #<- Error: "z2 is already used by cluster `cluster1`" 
```

You need to deploy at least **#azs * 2** `go-carbon` instances. This is due to a limitation in the current implementation of `buckytools` which does not support clusters formed by a single instance.

## Usage

To use this bosh release, first upload it to your bosh directly from the releases
section, or using the `yml` file in the `releases` folder.

This release makes use of [Bosh links](https://bosh.io/docs/links.html) between
instance groups in order to setup automatically the carbon relays and the carbonzippers
(for carbon API). This an example of V2 manifest (for google cloud):

```
---
---
name: go-graphite-boshrelease
director_uuid: 01f1714f-0550-44c9-b024-20a738e79212

releases:
- name: go-graphite-boshrelease
  version: latest

stemcells:
- alias: trusty
  name: bosh-google-kvm-ubuntu-trusty-go_agent
  version: 3312.6

instance_groups:
- name: smoke_tests
  instances: 1
  vm_type: common
  stemcell: trusty
  lifecycle: errand
  vm_extensions: []
  azs: [z1, z2]
  networks:
  - name: tools
  jobs:
  - name: smoke-tests
    release: go-graphite-boshrelease
    properties:
      smoke_tests:
        api_host: "10.255.3.251"
        api_port: 10000
        host: "10.255.3.250"
        port: 2003
        tcp_enabled: true
        udp_enabled: false

- name: graphite-backend
  instances: 4
  persistent_disk_pool: graphite-disks
  vm_type: graphite-backend
  stemcell: trusty
  vm_extensions: [graphite-api-europe-west1-backend-service]
  azs: [z1, z2]
  networks:
  - name: tools
  jobs:
  - name: go-carbon
    release: go-graphite-boshrelease
    properties:
      go-carbon:
        tcp_listen: 2030
        schemas:
        - name: stats
          pattern: '^stats\..*'
          retentions: '10:8d'
        - name: default
          pattern: '.*'
          retentions: '60s:14d'
        aggregations:
        - name: team1_stats_sum
          pattern: '^stats\.services\.team1\..*\.live\.event\..*\.sum$'
          aggregationMethod: sum
          xFilesFactor: 0.0
        - name: team1_counts_stats_sum
          pattern: '^stats_counts\.services\.team1\..*\.live\.event\..*\.sum$'
          aggregationMethod: sum
          xFilesFactor: 0.0
        carbonserver:
          enabled: true
          port: 8080
          host: "0.0.0.0"

  - name: carbonzipper
    release: go-graphite-boshrelease
    properties:
      carbonzipper:
        port: 9090

  - name: carbonapi
    release: go-graphite-boshrelease
    properties:
      carbonapi:
        port: 10000

  - name: statsd
    release: go-graphite-boshrelease
    properties:
      statsd:
        graphiteHost: "10.255.3.250"
        graphitePort: 2003
        percentThreshold: [90, 95, 99]

- name: carbon-c-relay
  instances: 2
  vm_type: graphite-relay
  vm_extensions: [graphite-europe-west1-backend-service]
  stemcell: trusty
  azs: [z1, z2]
  networks:
  - name: tools
  jobs:
  - name: carbon-c-relay
    release: go-graphite-boshrelease
    properties:
      carbon-c-relay:
        clusters:
          - name: "cluster1"
            lb: "jump_fnv1a_ch"
            replication: 1
            azs: ["z1"]
          - name: "cluster2"
            lb: "jump_fnv1a_ch"
            replication: 1
            azs: ["z2"]
  - name: statsrelay
    release: go-graphite-boshrelease
    properties:
      statsrelay:
        port: 8125

# recommend serial True if there are a lot of nodes (TODO)
update:
  canaries: 1
  max_in_flight: 1
  serial: true
  canary_watch_time: 1000-60000
  update_watch_time: 1000-60000

```

For [bosh-lite](https://github.com/cloudfoundry/bosh-lite), you can quickly create a deployment manifest & deploy a cluster:

```
templates/make_manifest warden
bosh -n deploy
```

## Development

As a developer of this release, you have to be aware of some requirements on your
local computer, mainly regarding golang and VCS.

The golang projects `carbonzipper` and `carbonapi` do not provide a way to manage
library dependencies, they are just using `go get` which is a wrapper around git
and it always fetchs from master, which makes difficult to create reproducible bosh
releases. The idea behind BOSH is making use of blobs which are the external source
components packed, so, in order to get a source code blob for those components,
you have to run `bosh_prepare` (on the root folder), which will create them with all
the dependencies inside by executing `packages/<package>/prepare`.

Requirements for `bosh_prepare`:

* golang (tested with golang 1.8)
* mercurial VCS (hg backend for some golang libs)
* git VCS

Then, you can run `bosh_prepare` to download all the source code blobs
(and optionally upload them to the blobstore).


Steps to build a new release:

```
git clone https://github.com/SpringerPE/go-graphite-boshrelease.git
cd go-graphite-boshrelease
bosh target BOSH_HOST
./bosh_prepare
bosh create release --force && bosh upload release
```


### Final releases

In order to publish a final release, you can run `./bosh_final_release` for:

* Upload all blobs to the public S3 bucket (and set them to public)
* Create a final Bosh release (increasing the version number)
* Upload and publish the new boshrelease tgz file in GitHub releases section, so
  you can point it directly in the manifest file (sha1 checksum is also calculated)
* Pushes and commits the changes to git

After that, you can also, upload the new release to bosh director `bosh upload release`


#### Smoke tests

The release provides a job ro run smoke tests as a Bosh errand `bosh run errand smoke_tests`.
See the previous manifest for the configuration of the errand.


## Authors

Springer Nature Platform Engineering,

Claudio Benfatto
Jose Riguera


Copyright 2017 Springer Nature

