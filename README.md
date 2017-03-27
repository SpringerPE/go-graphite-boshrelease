# BOSH Release for go-graphite

The aim of this bosh release is to deploy a go-graphite cluster consisting of the following components:

* [carbon-c-relay](https://github.com/grobian/carbon-c-relay) for metrics relaying and fordwarding
* [go-carbon](https://github.com/lomik/go-carbon) sever to storage metrics
* [carbonzipper](https://github.com/dgryski/carbonzipper) to transparently merge graphite carbon backends
* [carbonapi](https://github.com/dgryski/carbonapi) to provide the graphite API 


## Usage

To use this bosh release, first upload it to your bosh directly from the releases
section, or using the `yml` file in the `releases` folder.

This release makes use of [Bosh links](https://bosh.io/docs/links.html) between
instance groups in order to setup automatically the carbon relays and the carbonzippers
(for carbon API). This an example of V2 manifest:

```
---
name: go-graphite-boshrelease
# replace with `bosh status --uuid`
director_uuid: CHANGE_ME

releases:
- name: go-graphite
  version: latest

stemcells:
- alias: trusty
  name: bosh-vsphere-esxi-ubuntu-trusty-go_agent
  version: latest

instance_groups:
- name: test
  instances: 2
  vm_type: small
  stemcell: trusty
  vm_extensions: []
  azs:
  - Online_Prod
  networks:
  - name: online_tools
  jobs:
  - name: go-carbon
    release: go-graphite
    properties:
      go-carbon:
        tcp_listen: 2030
        schemas:
        - name: stats
          pattern: '^stats\..*'
          retentions: '10:8d'
        - name: netapp
          pattern: '^netapp\..*'
          retentions: '60s:14d'
          retentions: '60s:1d,600s:8d'
        - name: default
          pattern: '.*'
          retentions: '60s:14d'
        aggregations:
        - name: anura_counts_stats_sum
          pattern: '^stats_counts\.services\.anura\..*\.live\.event\..*\.sum$'
          aggregationMethod: sum
          xFilesFactor: 0.0
        udp:
          enabled: true
          port: 2030
        carbonserver:
          enabled: true
          port: 8080
          host: "0.0.0.0"
          read_timeout: "50s"
          write_timeout: "50s"
  - name: carbonzipper
    release: go-graphite-boshrelease
    properties:
      carbonzipper:
        port: 9090
        backends:
          - "http://127.0.0.1:8080"
  - name: carbon-c-relay
    release: go-graphite-boshrelease
    properties:
      carbon-c-relay:
        replication: 1
        backends: 
        - host: localhost
          port: 2030

- name: smoke_tests
  instances: 1
  vm_type: small
  stemcell: trusty
  lifecycle: errand
  vm_extensions: []
  azs:
  - Online_Prod
  networks:
  - name: online_tools
  jobs:
  - name: smoke-tests
    release: go-graphite
    properties:
      smoke_tests:
        api_host: CHANGE_ME
        api_port: 80
        host: CHANGE_ME
        port: 2003
        tcp_enabled: true
        udp_enabled: false

update:
  canaries: 1
  max_in_flight: 1
  serial: false
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

