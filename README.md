### Отчет о тестировании поведения распределения виртуальной и физической памяти

Проверяем влияния различных режимов доступа (чтение/запись) на занимаемый объем физической памяти при распределении памяти с использованием функции `malloc()`. Тестирование проводилось в сравнительном режиме: в среде Linux и в имитационной среде Windows, запущенной через Wine.

#### Аппаратная среда

- CPU: Intel(R) Core(TM) i7-1065G7 CPU @ 1.30GHz
- memory: 16GiB

#### Шаги 
1. Запускать программу соответственно в режимах `r` (чтение) и `w` (запись)
2. Наблюдать за состоянием использования памяти в инструменте мониторинга системы
3. Записывать изменения физической памяти и виртуальной памяти
4. Приостанавливать процесс после каждого распределения 128 MiB памяти и фиксировать полученные результаты наблюдения

- **Размер страницы**: 4 КБ 
- **Шаг распределения**: 128 МБ
- **Настройка задержки**: 100 микросекунд на доступ к странице
- **Максимальное распределение**: 4 ГБ 

#### Результаты тестирования системы Linux
>  Ubuntu 24.04.1 LTS

Напишем shell-скрипт для отслеживания изменений в виртуальной и физической памяти в режиме реального времени!!([monitor.sh](https://github.com/xiangxiang3451/virtual-physical-memory/blob/main/monitor.sh))

##### Read

Запустить нашу программу после запуска скрипта

```shell
 ./monitor.sh
```

```shell
./memory_test r
```

![](https://github.com/xiangxiang3451/virtual-physical-memory/blob/main/images/1.png?raw=true)

![](https://github.com/xiangxiang3451/virtual-physical-memory/blob/main/images/2.png?raw=true)

##### Write

```shell
 ./monitor.sh
```

```shell
./memory_test w
```

![](https://github.com/xiangxiang3451/virtual-physical-memory/blob/main/images/5.png?raw=true)

![](https://github.com/xiangxiang3451/virtual-physical-memory/blob/main/images/3.png?raw=true)

![](https://github.com/xiangxiang3451/virtual-physical-memory/blob/main/images/4.png?raw=true)

