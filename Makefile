
IMAGE = caiok/bookkeeper:4.4.0
BOOKIE ?= 1
DOCKER_NETWORK = bk_network

CONTAINER_NAME = bookkeeper-$(BOOKIE)
DOCKER_HOSTNAME = hostname
BK_LOCAL_DATA_DIR = /tmp/test_bk
BK_LOCAL_CONTAINER_DATA_DIR = $(BK_LOCAL_DATA_DIR)/$(CONTAINER_NAME)

ZK_CONTAINER_NAME=test_zookeeper
ZK_LOCAL_DATA_DIR=$(BK_LOCAL_DATA_DIR)/zookkeeper

CONTAINER_IP=$(shell docker inspect --format '{{ .NetworkSettings.IPAddress }}' $(CONTAINER_NAME))

#NOCACHE=--no-cache
NOCACHE=

# -------------------------------- #

.PHONY: all build run create start stop shell exec root-shell root-exec info ip clean-files clean

# -------------------------------- #

all:
	make info

# -------------------------------- #

build:
	-docker rmi -f $(IMAGE)
	time docker build \
	    $(NOCACHE) \
	    -t $(IMAGE) .

# -------------------------------- #

run-bk:
	# Temporary gimmick: clear all data because of bookkeeper blocking check on host / data integrity
	#-sudo rm -rf $(BK_LOCAL_CONTAINER_DATA_DIR)
	
	mkdir -p $(BK_LOCAL_DATA_DIR) \
			$(BK_LOCAL_CONTAINER_DATA_DIR) \
			$(BK_LOCAL_CONTAINER_DATA_DIR)/journal \
			$(BK_LOCAL_CONTAINER_DATA_DIR)/ledger \
			$(BK_LOCAL_CONTAINER_DATA_DIR)/index
	
	-docker rm -f $(CONTAINER_NAME)
	docker run -it\
		--network $(DOCKER_NETWORK) \
	    --volume $(BK_LOCAL_CONTAINER_DATA_DIR)/journal:/data/journal \
	    --volume $(BK_LOCAL_CONTAINER_DATA_DIR)/ledger:/data/ledger \
	    --volume $(BK_LOCAL_CONTAINER_DATA_DIR)/index:/data/index \
	    --name "$(CONTAINER_NAME)" \
	    --hostname "$(CONTAINER_NAME)" \
	    --env ZK_SERVERS=$(ZK_CONTAINER_NAME):2181 \
	    $(IMAGE)

# -------------------------------- #

run-format:
	docker run -it --rm \
		--network $(DOCKER_NETWORK) \
		--env ZK_SERVERS=$(ZK_CONTAINER_NAME):2181 \
		$(IMAGE) \
		bookkeeper shell metaformat

# -------------------------------- #

run-zk:

	-docker network create $(DOCKER_NETWORK)
	mkdir -pv $(BK_LOCAL_DATA_DIR) $(ZK_LOCAL_DATA_DIR) $(ZK_LOCAL_DATA_DIR)/data $(ZK_LOCAL_DATA_DIR)/datalog
	-docker rm -f $(ZK_CONTAINER_NAME)
	docker run -it --rm \
		--network $(DOCKER_NETWORK) \
		--name "$(ZK_CONTAINER_NAME)" \
		--hostname "$(ZK_CONTAINER_NAME)" \
		-v $(ZK_LOCAL_DATA_DIR)/data:/data \
		-v $(ZK_LOCAL_DATA_DIR)/datalog:/datalog \
		-p 2181:2181 \
		zookeeper

# -------------------------------- #

run-dice:
	docker run -it --rm \
		--network $(DOCKER_NETWORK) \
		--env ZOOKEEPER_SERVERS=$(ZK_CONTAINER_NAME):2181 \
		caiok/bookkeeper-tutorial

# -------------------------------- #

run-demo:
	$(eval WAIT_CMD := read -p 'Press Enter to close...')
	-sudo rm -rf $(BK_LOCAL_DATA_DIR)
	x-terminal-emulator -e "bash -c \"make run-zk ; $(WAIT_CMD)"\"
	sleep 5
	x-terminal-emulator -e "bash -c \"make run-format ; make run-bk BOOKIE=1 ; $(WAIT_CMD)\""
	sleep 3
	x-terminal-emulator -e "bash -c \"make run-bk BOOKIE=2 ; $(WAIT_CMD)\""
	x-terminal-emulator -e "bash -c \"make run-bk BOOKIE=3 ; $(WAIT_CMD)\""
	sleep 6
	x-terminal-emulator -e "bash -c \"make run-dice ; $(WAIT_CMD)\""
	sleep 2
	x-terminal-emulator -e "bash -c \"make run-dice ; $(WAIT_CMD)\""

# -------------------------------- #

start:
	docker start "$(CONTAINER_NAME)"

# -------------------------------- #

stop:
	docker stop "$(CONTAINER_NAME)"

# -------------------------------- #

shell exec:
	docker exec -it \
	    "$(CONTAINER_NAME)" \
	    /bin/bash -il

# -------------------------------- #

root-shell root-exec:
	docker exec -it "$(CONTAINER_NAME)" /bin/bash -il

# -------------------------------- #

info ip:
	@echo 
	@echo "Image: $(IMAGE)"
	@echo "Container name: $(CONTAINER_NAME)"
	@echo
	-@echo "Actual Image: $(shell docker inspect --format '{{ .RepoTags }} (created {{.Created }})' $(IMAGE))"
	-@echo "Actual Container: $(shell docker inspect --format '{{ .Name }} (created {{.Created }})' $(CONTAINER_NAME))"
	-@echo "Actual Container IP: $(shell docker inspect --format '{{ .NetworkSettings.IPAddress }}' $(CONTAINER_NAME))"
	@echo

# -------------------------------- #

clean-files:
	

clean:
	-docker stop $(CONTAINER_NAME)
	-docker rm $(CONTAINER_NAME)
	-docker rmi $(IMAGE)
	make clean-files
