include ./srcs/.env

COMPOSE_FILE := srcs/docker-compose.yml
VOLUMES_DIRS := $(VOLUMES_ROOT)/mariadb \
                $(VOLUMES_ROOT)/wordpress \
                $(VOLUMES_ROOT)/certs

all: up

up: .docker_up

.docker_up: $(COMPOSE_FILE)
	mkdir -p $(VOLUMES_DIRS)
	docker compose -f $(COMPOSE_FILE) up -d --build
	touch $@

down:
	docker compose -f $(COMPOSE_FILE) down -v --remove-orphans
	rm -f .docker_up

re: down up

logs:
	docker compose -f $(COMPOSE_FILE) logs -f

clean: down
	rm -rf $(VOLUMES_DIRS)

fclean: clean
	rm -rf $(VOLUMES_ROOT)

.PHONY: all down re logs clean fclean
