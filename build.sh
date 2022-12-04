set -x

ver="1.3"
img="starina/nwaf-dyn-ce-nginx-ui"

docker build --network host -t ${img}:${ver} -t ${img}:latest . \
&& docker push ${img}:${ver} \
&& docker push ${img}:latest
