set -x

ver="1.7"
img="starina/nwaf-dyn-ce-nginx-ui"
latest="test"

docker build --network host -t ${img}:${ver} -t ${img}:${latest} . \
&& docker push ${img}:${ver} \
&& docker push ${img}:${latest}
