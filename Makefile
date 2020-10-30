start: docker_start
	docker-compose exec superset superset-init

stop: docker_stop

docker_start:
	docker-compose up -d --renew-anon-volumes

docker_stop:
	docker-compose down

clean:
	docker container prune -f
	docker volume prune -f
