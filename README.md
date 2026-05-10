# Sobre o Orquest — Kanbook com Agentes opencode

## Como funciona

O **Orquest** é um sistema Kanban onde cada card é um arquivo `.md` dentro da pasta `orquestrator/` do seu repositório.

```
meu-repo/
├── orquestrator/
│   ├── 001-card.md
│   ├── 002-card.md
│   └── ...
├── src/
├── config/
└── ...
```

### App guarda apenas:

- Workspaces (alias + path do repositório)
- Estado runtime (sessão tmux rodando, status do agente)

### Cards são os `.md`:

- Cada `.md` = um card
- Ao adicionar um card pela UI, ele é escrito como `.md` no repositório
- Ao remover um projeto, os `.md` não são mais lidos → cards somem
- **Source of truth é o .md**, não o app

## Template do Card (.md)

```markdown
# Título do Card

tags: backend, auth, refactor
priority: 1
status: backlog

Body/descrição do card — isso é enviado para o agente.
Pode conter markdown, checklist, links, etc.
```

| Campo       | Descrição                              |
| ----------- | -------------------------------------- |
| `# Título`  | Título do card (obrigatório)           |
| `tags:`     | Tags separadas por vírgula             |
| `priority:` | 1 (Urgente) a 5 (Mínima)               |
| `status:`   | backlog \| todo \| in_progress \| done |
| (corpo)     | Texto markdown enviado para IA         |

> **Apenas o body (corpo) é enviado para o agente.**
> Tags, prioridade e título são metadados visuais/organizacionais.

## opencode

O Orquest usa o **opencode** como executor dos cards.

Cada card ao ser iniciado (Start Agent):

1. Cria uma sessão **tmux** com o workspace do card
2. Escreve o body do card como `TASK.md` no workspace
3. Executa automaticamente:
   ```
   opencode run "body do card"
   ```
4. O output é capturado e mostrado no card quando concluído

### O opencode herda as configurações do sistema

O `opencode` usado é o mesmo instalado no seu ambiente. Isso significa que:

- **Modelos**: usa o modelo configurado no seu `~/.opencode/config.yml` (deepseek, gpt-4, claude, etc.)
- **Ferramentas**: todas as ferramentas disponíveis no opencode (edição de arquivos, shell, etc.)
- **Contexto**: o agente tem acesso ao workspace inteiro do card, que é criado dentro do repositório do projeto
- **Configurações**: system prompt personalizado, regras de estilo, etc.

### Acompanhamento

Durante a execução, você pode:

- **Copiar o comando tmux** clicando em `tmux: orquest-xxx` no card
- **Anexar na sessão**: `tmux attach-session -t orquest-xxx`
- **Matar o agente**: clicar em "Kill Session" no card
- **Ver o output**: quando concluído, clicar em "Show output" no card

## Fluxo de trabalho

```
[Backlog] → "Mover para Todo" → [Todo] → "Start Agent" → [Running] → [Done]
                                    ↑                              ↓
                              "Mover para Backlog"           Kill Session
```

1. Cria ou escreve o card no backlog (ou escreve o `.md` direto no repositório)
2. Move para Todo
3. Start Agent → abre tmux + executa opencode com o body do card
4. Acompanha pelo tmux
5. Quando termina, o card vai para Done com o output capturado

## Benefícios

- **Versionado**: cards estão no Git junto com o código
- **Portátil**: qualquer pessoa com o repositório tem os cards
- **Editor livre**: pode escrever/editar cards direto no `.md` com seu editor favorito
- **IA configurável**: usa seu modelo preferido no opencode
- **Workspaces isolados**: cada card roda em seu próprio workspace
