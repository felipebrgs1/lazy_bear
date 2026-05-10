# Orquest

**Orquest** é um Kanban board inteligente que orquestra agentes autônomos. Cada card no board representa uma tarefa que pode ser executada automaticamente por um agente **opencode** em uma sessão **tmux**.

Os workspaces são criados dentro do próprio diretório do projeto, seguindo a estrutura:

```
<projeto>/orquestor/<nome-da-tarefa>/
```

Isso permite que o agente tenha **contexto completo do projeto** e o progresso fique visível diretamente no diretório do projeto.

## Como funciona

1. **Crie cards** no backlog descrevendo tarefas (ex: "Refatorar módulo X", "Implementar feature Y")
2. **Defina o projeto** — cada card pode ter um caminho de projeto (ex: `/saas1`)
3. **Mova para "To Do"** — um botão **Start Agent** aparece no card
4. **Clique em Start** — o card é movido para "In Progress" e fica **lockado**
5. Uma pasta é criada em `<projeto>/orquestor/<slug-do-titulo>/` com um `TASK.md`
6. Uma sessão **tmux** é iniciada com **opencode** apontando para o `TASK.md`
7. O agente executa a tarefa com acesso a todo o contexto do projeto
8. Quando a sessão tmux encerra, o card é movido para **"Done"**

## Funcionalidades

- Board Kanban com 5 colunas: Backlog, To Do, In Progress, Review, Done
- Workspaces **baseados em projetos** — cada tarefa vira uma pasta dentro do projeto
- Botão **Start Agent** para disparar execução manual de tarefas
- Cards **lockados** enquanto estão em execução (não podem ser editados ou deletados)
- Integração com **tmux** + **opencode** para execução real de agentes
- Monitoramento automático de sessões ativas a cada 5 segundos
- Fallback para `/tmp/orquest_workspaces/` quando nenhum projeto é especificado
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

### 1. Criar tarefa com projeto

No backlog, digite o título da tarefa e opcionalmente o caminho do projeto:

```
+------------------------------------------+
| Refatorar módulo de pagamentos      [ADD] |
| /saas1                                    |
+------------------------------------------+
```

### 2. Editar detalhes

Clique no card para abrir o modal de edição. Preencha:
- **Título** — nome da tarefa
- **Descrição** — instruções detalhadas para o agente opencode
- **Projeto** — caminho raiz do projeto (ex: `/home/user/saas1`)

### 3. Executar

1. Arraste o card para a coluna **To Do**
2. Clique em **Start Agent**
3. O card move para **In Progress** com um cadeado
4. A pasta de trabalho é criada em `<projeto>/orquestor/<slug-do-titulo>/`
5. A sessão tmux aparece no card como `tmux: orquest-<id>`
6. Acompanhe a execução: `tmux attach -t orquest-<id>`
7. Quando o opencode terminar, o card vai automaticamente para **Done**

### Exemplo de estrutura gerada

```
/saas1/
  orquestor/
    refatorar-modulo-de-pagamentos/
      TASK.md        ← descrição da tarefa
      ...            ← outputs do opencode
```

## Estrutura do projeto

```
lib/
  orquest/
    kanban/           # Lógica do board (Board, Column, Card)
      board.ex        # Operações do board (mover, adicionar, remover cards)
      card.ex         # Struct do card (title, description, project_path, tmux_session)
      column.ex       # Struct da coluna
    kanban.ex         # Contexto Agent que gerencia o estado em memória
    orchestrator.ex   # GenServer que cria/monitora sessões tmux + opencode
    workspace.ex      # Gerencia workspaces (borrow/return em diretórios de projeto)
    application.ex    # Árvore de supervisão
  orquest_web/
    live/kanban_live.ex  # LiveView do board
    router.ex            # Rotas
```

## Arquitetura

```
Usuário → LiveView → Kanban.start_card/1
                         ├── move_card("in_progress")
                         ├── Workspace.borrow(project_path, note_slug)
                         │     └── Cria <project_path>/orquestor/<slug>/
                         ├── update_card(%{agent_status: "running", ...})
                         └── Orchestrator.start_agent()
                               ├── Escreve TASK.md no workspace
                               ├── tmux new-session -d -s orquest-<id> -c <workspace>
                               ├── tmux send-keys "opencode TASK.md"
                               └── Polling: tmux has-session a cada 5s
                                     └── Sessão morreu → move_card("done")
```
