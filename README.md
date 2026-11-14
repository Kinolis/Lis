# LIS — кино начинается здесь

Новый интерфейс LIS на React + Vite. Сейчас это демонстрационная версия: каталог и избранное работают локально в браузере, без авторизации и серверной базы.

## Локальный запуск

```bash
npm install
npm run dev
```

## Сборка

```bash
npm run build
```

Результат сборки находится в папке `dist`.

## Публикация через Cloudflare Pages

Подключить репозиторий `Kinolis/Lis` в Cloudflare Pages и указать:
- Framework preset: **Vite**
- Build command: **npm run build**
- Build output directory: **dist**
- Root directory: **/**

Не использовать команду `npx wrangler deploy`: это команда для деплоя Worker, а данный проект является статическим сайтом для Pages.
