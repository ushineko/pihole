.PHONY: start stop update status logs shell help

# Default target
.DEFAULT_GOAL := help

# Extract help comments from Makefile
HELP_FUN = \
    %help; \
    while(<>) { \
        if(/^([a-zA-Z0-9_-]+):.*\#\#\@(\w+)\s+(.*)$$/) { \
            push(@{$$help{$$2}}, [$$1, $$3]); \
        } \
    }; \
    print "Usage: make [target]\n\n"; \
    for (sort keys %help) { \
        print "$$_:\n"; \
        for (@{$$help{$$_}}) { \
            $$sep = " " x (32 - length $$_->[0]); \
            print "  $$_->[0]$$sep$$_->[1]\n"; \
        } \
        print "\n"; \
    }

help: ##@misc Show this help message
	@perl -e '$(HELP_FUN)' $(MAKEFILE_LIST)

# Run the setup script for first-time configuration
setup: ##@main Run the setup script to initialize configurations
	@echo "Running setup script..."
	@./scripts/setup.sh

# Start the container
start: setup ##@main Start the Pi-hole container
	@echo "Starting Pi-hole..."
	docker compose up -d

# Stop the container
stop: ##@main Stop the Pi-hole container
	@echo "Stopping Pi-hole..."
	docker compose down

# Update the container and restart
update: ##@main Update and restart the Pi-hole container
	@echo "Updating Pi-hole..."
	docker compose pull
	docker compose down
	docker compose up -d

# Show container status
status: ##@info Show Pi-hole container status
	@echo "Pi-hole status:"
	docker compose ps

# Show container logs
logs: ##@info Show Pi-hole container logs
	docker compose logs -f pihole

# Access container shell
shell: ##@info Access Pi-hole container shell

# Test DNS resolution and blocking
test: ##@info Test DNS functionality and ad blocking
	@echo "Checking Pi-hole status..."
	@docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	@if [ -f .env ]; then export $$(grep -v '^#' .env | xargs); fi; \
	PI_IP=$${PIHOLE_HOST_IP:-127.0.0.1}; \
	echo "\nTesting external resolution (google.com) on $$PI_IP..."; \
	dig +short @$$PI_IP google.com | grep -E '^[0-9.]+' > /dev/null && echo "✅ Resolution OK" || (echo "❌ Resolution FAILED"; exit 1); \
	echo "\nTesting ad blocking (doubleclick.net)..."; \
	res=$$(dig +short @$$PI_IP doubleclick.net); \
	if [ "$$res" = "0.0.0.0" ]; then \
		echo "✅ Blocking OK (Returned $$res)"; \
	else \
		echo "❌ Blocking FAILED (Returned $$res)"; \
		exit 1; \
	fi

# Flush Pi-hole logs (Clear history)
flush: ##@main Flush Pi-hole logs and clear dashboard history
	@docker compose exec pihole sh -c "pihole -f 2> /dev/null"
	@docker compose restart pihole
 