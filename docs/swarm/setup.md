# 🐳 Docker Swarm Setup

## Initialize the Swarm
Initialize the swarm using the node's IP address:
```bash
ssh subeedei docker swarm init --advertise-addr 10.0.0.20
```

When you run this command, Docker will output a join token for worker nodes that looks similar to:
```
docker swarm join --token SWMTKN-1-49nj1cmql0jkz5s954yi3oex3nedyz0fb0xx14ie39trti4wxv-8vxv8rssmk743ojnwacrr2e7c 10.0.0.20:2377
```

Save this token for adding worker nodes later.

## Get Manager Join Token
Get the join token for additional manager nodes:
```bash
ssh subeedei docker swarm join-token manager
```

This will output a command similar to:
```
docker swarm join --token SWMTKN-1-49nj1cmql0jkz5s954yi3oex3nedyz0fb0xx14ie39trti4wxv-2hgdazm5th4wgmamjdh6v1agh 10.0.0.20:2377
```

Save this token for adding the remaining manager nodes.

## Add Additional Manager Nodes
Join the swarm as a manager using the manager token from step 2:
```bash
ssh zev docker swarm join --token SWMTKN-1-49nj1cmql0jkz5s954yi3oex3nedyz0fb0xx14ie39trti4wxv-2hgdazm5th4wgmamjdh6v1agh 10.0.0.20:2377
ssh khubilai docker swarm join --token SWMTKN-1-49nj1cmql0jkz5s954yi3oex3nedyz0fb0xx14ie39trti4wxv-2hgdazm5th4wgmamjdh6v1agh 10.0.0.20:2377
```

## Add Worker Nodes
Join the swarm as a worker using the worker token from step 1:
```bash
ssh uriankhai docker swarm join --token SWMTKN-1-49nj1cmql0jkz5s954yi3oex3nedyz0fb0xx14ie39trti4wxv-8vxv8rssmk743ojnwacrr2e7c 10.0.0.20:2377
ssh besud docker swarm join --token SWMTKN-1-49nj1cmql0jkz5s954yi3oex3nedyz0fb0xx14ie39trti4wxv-8vxv8rssmk743ojnwacrr2e7c 10.0.0.20:2377
ssh baarin docker swarm join --token SWMTKN-1-49nj1cmql0jkz5s954yi3oex3nedyz0fb0xx14ie39trti4wxv-8vxv8rssmk743ojnwacrr2e7c 10.0.0.20:2377
```

## Verify Swarm Status
Check the swarm status:
```bash
ssh subeedei docker node ls
```

You should see output similar to:
```
ID                            HOSTNAME     STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
uvthouwe1xkcf4k9narwfzsbr *   subeedei     Ready     Active         Leader           24.0.5
a7nl4jfja6nt58ho0e81ogkxp     zev          Ready     Active         Reachable        24.0.5
nyd4bezt7t1fec3gi67yt797w     khubilai     Ready     Active         Reachable        24.0.5
g9b0llt8npotc3fg36gqbdcro     uriankhai    Ready     Active                          24.0.5
ghy3kowzahaw7jh1gl0ew7oel     besud        Ready     Active                          24.0.5
tby72nv2nz76qwpahbxhv17dy     baarin       Ready     Active                          24.0.5
```
