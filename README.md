# Release Helper

Призван помогать в создании релизов.

Положить папку `release-helper` на одном уровне с папками проекта

Запускать строго из папки `release-helper`

```
+-- classto
|---- clobl
|---- collectivoo
|---- classta-frontik
|---- ...
|---- release-helper
```

# Пример запуска

## Создать фичу
`./release-helper.sh create-branch master feature-TEST-3 "gvim -fp" meld`

## Зафиксировать зависимости в фиче
`./release-helper.sh freeze-branch master feature-TEST-3 "gvim -fp" meld`

## Создать релиз
`./release-helper.sh create-branch master release-20161228 "gvim -fp" meld`

## Замержить фичу в релиз
`./release-helper.sh merge-branch feature-TEST-3 release-20161228 "gvim -fp" meld`

## Замержить релиз в мастер
`./release-helper.sh merge-branch release-20161228 master "gvim -fp" meld`

## Создать хотфикс
`./release-helper.sh create-branch master hotfix-20170111 "gvim -fp" meld`

## Замержить хотфикс в мастер
`./release-helper.sh merge-branch hotfix-20170111 master "gvim -fp" meld`


# Дополнительные манипуляции

## Ручное редактирование package.json
`./release-helper.sh manual-edit master release-20161228 "gvim -fp" meld`

## Разморозить фичу
`./release-helper.sh unfreeze-branch master feature-TEST-3 "gvim -fp" meld`


# Настройка

В файле `devrepos` хранить список репозиториев имеющих `dev` ветку

В файле `excluderepos` хранить список репозиториев исключенных их обработки
