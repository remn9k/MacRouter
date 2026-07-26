<h1 align="center">
  <img src="assets/icon.png" width="64" height="64" alt="MacRouter Логотип" valign="middle">
  <br>
  MacRouter
</h1>

<p align="center">
  <b>Легкое нативное приложение macOS (Menu Bar) для управления 9router и Antigravity.</b>
</p>

<p align="center">
  <a href="README.md">English</a> • <b>Русский</b>
</p>

<p align="center">
  <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/платформа-macOS%2013%2B-blue?logo=apple" alt="Платформа"></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift" alt="Swift"></a>
  <a href="https://developer.apple.com/xcode/swiftui/"><img src="https://img.shields.io/badge/UI-SwiftUI-3A96DD?logo=swift" alt="SwiftUI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/лицензия-MIT-green.svg" alt="Лицензия"></a>
  <a href="https://t.me/remn9k"><img src="https://img.shields.io/badge/Telegram-@remn9k-26A5E4?logo=telegram" alt="Telegram"></a>
</p>

<p align="center">
  <a href="#возможности">Возможности</a> •
  <a href="#установка">Установка</a> •
  <a href="#структура-проекта">Структура</a> •
  <a href="#об-этом-проекте">О проекте</a>
</p>

---

<p align="center">
  <img src="assets/preview.png" width="380" alt="Скриншот MacRouter">
</p>

---

## Возможности

- **Тумблер управления сервером**: Быстрый запуск и остановка локального прокси-сервера прямо из строки меню macOS.
- **Мониторинг квот в реальном времени**: Раздельный подчет процентов доступности для моделей (**Gemini** и **Claude**) с цветовой индикацией.
- **Пинг задержки**: Проверка отклика всех подключенных аккаунтов в один клик.
- **Скрытие Email для приватности**: Маскирование e-mail адресов (`1l***11@gmail.com`) для стримов и скриншотов.
- **Скроллинг и настройки**: Настройка порта, логирование в файл, автозапуск при старте системы и переключение языка (RU/EN).
- **Нулевая нагрузка**: Нативный интерфейс на SwiftUI + AppKit с минимальным потреблением ресурсов.

---

## Установка

### Вариант 1: Готовый релиз (Рекомендуется)

1. Скачайте свежий архив `MacRouter-macOS.zip` со страницы [Релизов](../../releases).
2. Распакуйте архив и перенесите `MacRouter.app` в папку `/Программы` (`/Applications`).
3. Запустите `MacRouter.app`. В строке меню рядом с часами появится оранжевая иконка.

### Вариант 2: Сборка из исходного кода

Требования: macOS 13.0+, Xcode Command Line Tools (`xcode-select --install`).

```bash
# Клонировать репозиторий
git clone https://github.com/remn9k/MacRouter.git
cd MacRouter

# Скомпилировать и упаковать релиз
./scripts/package.sh

# Запустить приложение
open MacRouter.app
```

---

## Структура проекта

```text
macrouter/
├── Package.swift               # Манифест сборки SwiftPM
├── AppIcon.icns                # Оранжевая Retina-иконка
├── assets/
│   ├── icon.png                # PNG Логотип
│   └── preview.png             # Скриншот интерфейса
├── Sources/
│   └── MacRouter/
│       ├── MacRouterApp.swift         # Главный модуль AppKit и NSPopover
│       ├── PopoverContentView.swift   # Интерфейс SwiftUI
│       ├── RouterProcessManager.swift # Взаимодействие с прокси-сервером и REST API
│       └── AutoStartManager.swift     # Настройка автозапуска (SMAppService)
├── scripts/
│   ├── package.sh              # Скрипт сборки релиза
│   └── generate_icon.swift     # Генератор иконки AppIcon.icns
├── README.md                   # Документация на английском
└── README_RU.md                # Документация на русском
```

---

## Об этом проекте

Этот репозиторий был создан примерно **на 90% с помощью ИИ**, так что вполне вероятно что тут что то будет не работать.

Если что-то не работает или есть вопросы:
- Пишите в Telegram: **[@remn9k](https://t.me/remn9k)**

---

## Лицензия

Распространяется под лицензией MIT. Подробности см. в файле `LICENSE`.
