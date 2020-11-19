start: docker_start_clean
	docker-compose exec superset superset-init

stop: docker_stop

docker_start_clean:
	docker-compose up -d --renew-anon-volumes

docker_start:
	docker-compose

docker_stop:
	docker-compose down

docker_ps:
	docker-compose ps

clean:
	docker container prune -f
	docker volume prune -f
