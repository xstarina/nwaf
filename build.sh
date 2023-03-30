set -x
set -e

ver="1.7.8.1"
img="starina/nwaf-dyn-ce-nginx-ui"
[ "$1" == 'test' ] && tag='test' || tag='latest'

docker pull nginx:1.22
docker build --network host -t ${img}:${ver} -t ${img}:${tag} .
[ "$tag" == 'latest' ] && for t in $ver $tag; do docker push $img:$t; done
