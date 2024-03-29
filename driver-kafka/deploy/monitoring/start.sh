#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


echo 'Starting Grafana...'

/run.sh "$@" &

AddDataSource() {
  curl 'http://admin:admin@localhost:3000/api/datasources' \
    -X POST \
    -H 'Content-Type: application/json;charset=UTF-8' \
    --data-binary \
    "{\"name\":\"Prometheus\",\"type\":\"prometheus\",\"url\":\"$PROMETHEUS_URL\",\"access\":\"proxy\",\"isDefault\":true}"
}

until AddDataSource; do
    echo 'Configuring Grafana...'
    sleep 1
done
    echo 'Done!'
wait