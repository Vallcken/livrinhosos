# Meus Livros

Site em Flutter Web (Dart) para gerenciar:

- **Lidos**: livros que você já leu, com nota (1–5 estrelas) e anotações.
- **Desejados**: sua lista de "quero ler". Dá para marcar como lido com um toque.
- **Top 5**: seus cinco favoritos, reordenáveis por arrastar e soltar.

Os dados ficam salvos no próprio navegador (localStorage), sem precisar de servidor.

## Como rodar

Requer o [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado.

```bash
cd meus_livros
flutter create . --platforms=web   # gera os arquivos de plataforma que faltam (não sobrescreve lib/ nem pubspec)
flutter pub get
flutter run -d chrome
```

## Gerar o site para publicar

```bash
flutter build web --release
```

A pasta `build/web` contém o site pronto. Pode ser hospedada no GitHub Pages, Firebase Hosting, Netlify, Vercel etc.

Para GitHub Pages em um subcaminho, use:

```bash
flutter build web --release --base-href "/nome-do-repositorio/"
```

## Regras do Top 5

- Só livros **lidos** podem entrar no Top 5.
- Máximo de 5 livros.
- Se um livro sair da lista de lidos (ou for excluído), ele sai do Top 5 automaticamente.
