# Orquest

**Orquest** é um Kanban board inteligente que orquestra agentes autônomos. Cada card no board representa uma tarefa que pode ser executada automaticamente por um agente **opencode** em uma sessão **tmux**.

## Como funciona

1. **Crie cards** no backlog descrevendo tarefas (ex: "Refatorar módulo X", "Implementar feature Y")
2. **Mova para "To Do"** — um botão **Start Agent** aparece no card
3. **Clique em Start** — o card é movido para "In Progress" e fica **lockado**
4. Uma sessão **tmux** é criada com **opencode** apontando para a descrição da tarefa
5. O agente executa a tarefa autonomamente
6. Quando a sessão tmux encerra, o card é movido para **"Done"**

## Funcionalidades

- Board Kanban com 5 colunas: Backlog, To Do, In Progress, Review, Done
- Botão **Start Agent** para disparar execução manual de tarefas
- Cards **lockados** enquanto estão em execução (não podem ser editados ou deletados)
- Integração com **tmux** + **opencode** para execução real de agentes
- Monitoramento automático de sessões ativas a cada 5 segundos
- Workspaces isolados em `/tmp/orquest_workspaces/`
- Tema dark/light
- Board atualizado em tempo real via PubSub

## Pré-requisitos

- **Elixir** ~> 1.14
- **Phoenix** ~> 1.7
- **tmux** instalado no sistema
- **opencode** instalado e disponível no `$PATH`

## Setup

```bash
# Instalar dependências
mix setup

# Iniciar servidor Phoenix
mix phx.server
```

Acesse [`localhost:4000`](http://localhost:4000) no navegador.

## Como usar

1. Na coluna **Backlog**, adicione uma tarefa digitando o título e clicando em ADD
2. Clique no card para editar e preencher a **descrição** da tarefa (é o que o agente opencode vai executar)
3. Arraste o card para a coluna **To Do**
4. Clique no botão **Start Agent** no card
5. O card move para **In Progress** com um cadeado — está lockado
6. A sessão tmux aparece com o nome `orquest-<id-do-card>`
7. Acompanhe a execução com `tmux attach -t orquest-<id>`
8. Quando o processo opencode terminar, o card é movido automaticamente para **Done**

## Estrutura do projeto

```
lib/
  orquest/
    kanban/           # Lógica do board (Board, Column, Card)
      board.ex        # Operações do board (mover, adicionar, remover cards)
      card.ex         # Struct do card (title, description, status, tmux_session)
      column.ex       # Struct da coluna
    kanban.ex         # Contexto Agent que gerencia o estado em memória
    orchestrator.ex   # GenServer que cria/monitora sessões tmux + opencode
    workspace.ex      # Gerencia workspaces físicos (borrow/return)
    application.ex    # Árvore de supervisão
  orquest_web/
    live/kanban_live.ex  # LiveView do board
    router.ex            # Rotas
```

## Arquitetura

```
Usuário → LiveView → Kanban.start_card/1
                         ├── move_card("in_progress")
                         ├── Workspace.borrow()
                         ├── update_card(%{agent_status: "running", tmux_session: ...})
                         └── Orchestrator.start_agent()
                               ├── Cria diretório workspace com TASK.md
                               ├── tmux new-session -d -s orquest-<id>
                               ├── tmux send-keys "opencode TASK.md"
                               └── Polling: tmux has-session a cada 5s
                                     └── Quando morre → move_card("done")
```
