# Dashboard de Auditoria OpenVPN (Docker + PostgreSQL)

Este projeto contém um script de instalação rápida para subir um dashboard estático de auditoria de acessos OpenVPN, junto a uma stack Docker com Nginx, PostgreSQL e pgAdmin. O script automatiza a instalação de dependências, provisiona a estrutura de diretórios em `/opt/openvpn-audit`, cria os arquivos necessários (HTML, CSS, Nginx, docker-compose, SQL de inicialização) e inicia os serviços.

## Visão geral
- **Frontend (estático)**: HTML/CSS/Bootstrap + ícones Font Awesome (copiados localmente) com páginas: Dashboard, Usuários, Documentos, Alertas e Relatórios.
- **Nginx**: Servidor web para servir o conteúdo estático.
- **PostgreSQL**: Banco de dados `openvpn_audit` com tabelas `usuarios` e `auditoria`, índices e gatilhos.
- **pgAdmin**: Interface web para administração do PostgreSQL.

Script principal: `dashboard-auditoria.sh` (nome interno citado: `install_openvpn_audit_postgres_menus.sh`).

## Requisitos
- Acesso root (executar com `sudo`)
- Linux suportado: Ubuntu/Debian, CentOS/RHEL/Rocky/Alma, Fedora
- Acesso à internet (downloads de pacotes, imagens Docker e Font Awesome)

O script instala automaticamente, se necessário:
- Docker
- Docker Compose
- Pacotes de sistema (curl, wget, unzip, git, etc.)

## Estrutura provisionada
```
/opt/openvpn-audit/
  ├─ html/              # páginas estáticas (index.html, css, webfonts, pages)
  ├─ nginx/
  │   ├─ nginx.conf
  │   └─ default.conf
  ├─ postgres/
  │   └─ init.sql       # criação de tabelas, índices e dados exemplo
  ├─ backup/            # backups gerados por backup.sh
  ├─ docker-compose.yml
  ├─ start.sh           # inicia os serviços
  └─ stop.sh            # para os serviços
```

## Banco de dados
- Container: `openvpn_audit_postgres` (imagem `postgres:15-alpine`)
- DB: `openvpn_audit`
- Usuário: `audituser`
- Senha: `auditpass123`
- Porta: `5432`
- Extensão habilitada: `pg_stat_statements`

`postgres/init.sql` cria:
- Tabela `usuarios` (`login`, `data_inicio`, `data_fim`, `status_documentacao` = OK|Faltando, links e timestamps)
- Tabela `auditoria` (ações por usuário)
- Trigger para atualizar `updated_at` em `usuarios`
- Índices em colunas-chave e dados de exemplo

## Serviços e portas
- Nginx: 80 (serve `/opt/openvpn-audit/html`)
- PostgreSQL: 5432
- pgAdmin: 5050

Rede Docker: `openvpn_audit_network` (bridge) e volume `postgres_data` para persistência.

## Como executar
1. Dê permissão e execute como root:
   ```bash
   chmod +x dashboard-auditoria.sh
   sudo ./dashboard-auditoria.sh
   ```
2. Confirme a instalação quando solicitado (`s`).
3. Acesse após concluir:
   - Dashboard: `http://localhost`
   - pgAdmin: `http://localhost:5050`
   - PostgreSQL: `localhost:5432`

Gerenciar serviços depois:
```bash
sudo /opt/openvpn-audit/start.sh
sudo /opt/openvpn-audit/stop.sh
```

Logs:
```bash
cd /opt/openvpn-audit && docker-compose logs -f
```

## Configurações
- Ajuste credenciais em `docker-compose.yml` para produção:
  - `POSTGRES_USER`, `POSTGRES_PASSWORD`, `PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD`
- Edite `nginx/default.conf` e `nginx/nginx.conf` conforme sua política de segurança/domínio
- O frontend é estático (não consulta o DB). Para dados dinâmicos, crie uma API e integre.

## Backup e restauração
- Backup:
  ```bash
  sudo /opt/openvpn-audit/backup.sh
  ```
  Gera dump SQL e tar.gz de HTML/configs em `/opt/openvpn-audit/backup`.

- Restauração (resumo):
  1) Suba o Postgres com `docker-compose`.
  2) Restaure o dump:
     ```bash
     docker exec -i openvpn_audit_postgres psql -U audituser -d openvpn_audit < /caminho/para/backup_database.sql
     ```

## Systemd (opcional)
Unidade criada: `openvpn-audit.service`.
```bash
sudo systemctl daemon-reload
sudo systemctl enable openvpn-audit
sudo systemctl start openvpn-audit
sudo systemctl status openvpn-audit | cat
```

## Segurança
- Altere todas as senhas padrão antes de expor
- Restrinja portas (firewall/SG) conforme necessário
- Avalie TLS no Nginx e uso de Docker secrets/variáveis

## Solução de problemas
- Docker não inicia: `systemctl status docker` e verifique usuário no grupo `docker`
- Portas em uso: ajuste mapeamentos (`80`, `443`, `5050`, `5432`) em `docker-compose.yml`
- pgAdmin não conecta: host `postgres`, porta `5432`, usuário `audituser`, senha
- Font Awesome ausente: reexecute o script para repopular `html/css` e `html/webfonts`

## Licença
Não especificada. Defina uma licença se necessário.
