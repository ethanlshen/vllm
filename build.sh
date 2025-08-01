# beaker image delete ethans/datagen
# docker image remove datagen:latest
# docker build -t datagen .
# beaker image create --name datagen datagen

beaker image delete ethans/fsdp_vllm
docker image remove fsdp_vllm:latest
docker build -t fsdp_vllm .
beaker image create --name fsdp_vllm fsdp_vllm