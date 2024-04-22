.DEFAULT_GOAL := help
SHELL=/bin/bash
APP_DIR=tests/Application
SYMFONY=cd ${APP_DIR} && symfony
COMPOSER=symfony composer
CONSOLE=cd ${APP_DIR} && docker-compose run --rm php bin/console
COMPOSE=docker-compose
DOCKER=cd ${APP_DIR} && docker-compose run --rm php bin/console sylius:install -s default -n
YARN=yarn
NPM=npm

###
### DEVELOPMENT
### ¯¯¯¯¯¯¯¯¯¯¯

HELP += $(call help,install,			Install the project)
install: application platform sylius theme ## Install the plugin
.PHONY: install

HELP += $(call help,reset,			Stop docker and remove project)
reset: ## Stop docker and remove dependencies
	${MAKE} platform_down || true
	rm -rf ${APP_DIR}/node_modules ${APP_DIR}/package-lock.json
	rm -rf ${APP_DIR}/vendor ${APP_DIR}/composer-lock.json
	rm -rf ${APP_DIR}
	rm -rf vendor composer.lock
.PHONY: rese

HELP += $(call help,stop,			Stop project)
stop:
	make platform_down

HELP += $(call help,stop,			Start project)
up:
	make platform_up

###
### TEST APPLICATION
### ¯¯¯¯¯

application: php.ini .php-version ${APP_DIR} ## Setup the entire Test Application

.php-version: .php-version.dist
	rm -f .php-version
	ln -s .php-version.dist .php-version

php.ini: php.ini.dist
	rm -f php.ini
	ln -s php.ini.dist php.ini

${APP_DIR}:
	(${COMPOSER} create-project --no-interaction --prefer-dist --no-scripts --no-progress --no-install sylius/sylius-standard="${SYLIUS_VERSION}" ${APP_DIR})
	cd ${APP_DIR} && chmod -R 777 public
	echo "COMPOSE_PROJECT_NAME=sylius_tailwindcss_theme" >> ${APP_DIR}/.env
	make apply_dist

apply_dist:
	ROOT_DIR=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST)))); \
	for i in `cd dist && find . -type f`; do \
		FILE_PATH=`echo $$i | sed 's|./||'`; \
		FOLDER_PATH=`dirname $$FILE_PATH`; \
		echo $$FILE_PATH; \
		(cd ${APP_DIR} && rm -f $$FILE_PATH); \
		(cd ${APP_DIR} && mkdir -p $$FOLDER_PATH); \
    done

###
### SYLIUS
### ¯¯¯¯¯¯¯¯
sylius: sylius_install install_bundle messenger

DOCKER_USER ?= "$(shell id -u):$(shell id -g)"
ENV ?= "dev"

sylius_install:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose exec -it -u root php rm -rf public/media/image)
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run php bin/console doctrine:database:drop --if-exists --force)
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run php bin/console sylius:install -s default -n)
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run php bin/console doctrine:query:sql "UPDATE sylius_channel SET theme_name = 'agence-adeliom/sylius-tailwindcss-theme'")
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run php bin/console sylius:theme:assets:install --symlink)

install_bundle:
	cd ${APP_DIR} && docker-compose run php composer require --no-interaction ${PLUGIN_NAME}="*@dev"
	rm -rf ${APP_DIR}/var/cache

messenger.setup: ## Setup Messenger transports
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run php bin/console messenger:setup-transports)

###
### PLATFORM
### ¯¯¯¯¯¯¯¯

platform:
	@if [ ! -e compose.override.yml ]; then \
		(cd ${APP_DIR} && cp compose.override.dist.yml compose.override.yml); \
		(cd ${APP_DIR} && sed -i'' -e 's|          - public-media:/srv/sylius/public/media:rw|          - public-media:/srv/sylius/public/media:rw\n          - ../../:/srv/sylius/themes/TailwindTheme:rw|g' compose.override.yml); \
		(cd ${APP_DIR} && sed -i'' -e 's|            - public-media:/srv/sylius/public/media:ro,nocopy|            - public-media:/srv/sylius/public/media:ro,nocopy\n            - ../../:/srv/sylius/themes/TailwindTheme:rw|g' compose.override.yml); \
		(cd ${APP_DIR} && sed -i'' -e 's|            - ./public:/srv/sylius/public:rw,delegated|            - ./public:/srv/sylius/public:rw,delegated\n            - ../../:/srv/sylius/themes/TailwindTheme:rw|g' compose.override.yml); \
		(cd ${APP_DIR} && rm -rf compose.override.yml-e); \
		(cd ${APP_DIR} && ENV=$(ENV) docker-compose --project-name sylius-tailwindcss-theme); \
	fi

	cd ${APP_DIR} && (ENV=$(ENV) docker-compose up -d --force-recreate )
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm php composer config github-oauth.github.com ${GITHUB_TOKEN})
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm php composer config minimum-stability dev)
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm php composer config extra.symfony.allow-contrib true)
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm php composer config repositories.plugin '{"type": "path", "url": "../../"}')
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm php composer config repositories.adeliom '{"type":"vcs","url":"git@github.com:agence-adeliom/sylius-tailwindcss-theme.git"}')
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm php composer config extra.symfony.require "~${SYMFONY_VERSION}")
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm php composer require --no-install --no-scripts --no-progress sylius/sylius="~${SYLIUS_VERSION}")
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm php composer require --no-install --no-scripts --no-progress --dev friendsoftwig/twigcs)
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm php composer dump-autoload)
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm php composer install --no-interaction --no-scripts --prefer-dist)
	make platform_up
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm nodejs)

platform_debug:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose -f compose.yml -f compose.override.yml -f compose.debug.yml up -d)

platform_up:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose up -d )

platform_down:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose down)

platform_clean:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose down -v)

php-shell:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose exec php sh)

node-shell:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm -i nodejs sh)

node-watch:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm -i nodejs "npm run watch")

###
### THEME
### ¯¯¯¯¯¯

theme: install-theme build-theme ## Install Theme
.PHONY: theme

install-theme:
	cp tailwind.config.js ${APP_DIR}
	cp postcss.config.js ${APP_DIR}
	echo "const tailwindTheme = require('./themes/TailwindTheme/webpack.config');" >> ${APP_DIR}/webpack.config.js
	echo "module.exports = [shopConfig, adminConfig, appShopConfig, appAdminConfig, tailwindTheme];" >> ${APP_DIR}/webpack.config.js
	echo "            tailwindTheme:" >> ${APP_DIR}/config/packages/assets.yaml
	echo "                json_manifest_path: '%kernel.project_dir%/public/themes/tailwind-theme/manifest.json'" >> ${APP_DIR}/config/packages/assets.yaml
	echo "        tailwindTheme: '%kernel.project_dir%/public/themes/tailwind-theme'" >> ${APP_DIR}/config/packages/webpack_encore.yaml
	echo "    webp:" >> ${APP_DIR}/config/packages/liip_imagine.yaml
	echo "        generate: true" >> ${APP_DIR}/config/packages/liip_imagine.yaml
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm nodejs "npm install tailwindcss @fortawesome/fontawesome-free daisyui")
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm nodejs "npm install postcss-loader@^7.0.0 autoprefixer --save-dev")
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm nodejs "npm install eslint --save-dev")

HELP += $(call help,build-theme,			Build theme)
build-theme:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm -i nodejs "npm run build:prod")
	echo "navigate to http://localhost:8050/"

HELP += $(call help,watch-theme,			Build & watch theme)
watch-theme:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm -i nodejs "npm run watch")

###
### TESTS
### ¯¯¯¯¯

test.all: test.composer test.schema test.twig ## Run all tests in once

test.composer: ## Validate composer.json
	${COMPOSER} validate --strict

# Check eslint
test.eslint:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose run --rm -i nodejs "cd themes/TailwindTheme && npm run lint")

# Check coding standard
test.ecs:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose exec php vendor/bin/ecs check ${PLUGIN_DIR}/src)

# Fix coding standard
test.ecs.fix:
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose exec php vendor/bin/ecs --fix check ${PLUGIN_DIR}/src)

HELP += $(call help,test.schema,			Validate MySQL Schema)
test.schema: ## Validate MySQL Schema
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose exec php bin/console doctrine:cache:clear-metadata)
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose exec php bin/console doctrine:schema:validate)

HELP += $(call help,test.twig,			Validate Twig templates)
test.twig: ## Validate Twig templates
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose exec php bin/console lint:twig --no-debug ${PLUGIN_DIR}/templates)
	cd ${APP_DIR} && (ENV=$(ENV) docker-compose exec php vendor/bin/twigcs ${PLUGIN_DIR}/templates --severity error --display blocking)
