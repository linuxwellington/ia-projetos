#!/bin/bash

# Script de Instalação Rápida Docker + Dashboard OpenVPN Audit (PostgreSQL)
# Versão com menus funcionais - Nome do arquivo: install_openvpn_audit_postgres_menus.sh

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções de logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# Verificar se é root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script precisa ser executado como root (sudo)"
        exit 1
    fi
}

# Detectar sistema operacional
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        error "Sistema operacional não suportado"
        exit 1
    fi
    
    log "Sistema detectado: $OS $VER"
}

# Atualizar sistema
update_system() {
    log "Atualizando sistema..."
    
    if [[ $OS == *"Ubuntu"* ]] || [[ $OS == *"Debian"* ]]; then
        apt-get update -y
        apt-get upgrade -y
    elif [[ $OS == *"CentOS"* ]] || [[ $OS == *"Red Hat"* ]] || [[ $OS == *"Rocky"* ]] || [[ $OS == *"Alma"* ]]; then
        yum update -y
    elif [[ $OS == *"Fedora"* ]]; then
        dnf update -y
    else
        warning "Sistema não reconhecido, pulando atualização"
    fi
    
    success "Sistema atualizado"
}

# Instalar dependências
install_dependencies() {
    log "Instalando dependências..."
    
    if [[ $OS == *"Ubuntu"* ]] || [[ $OS == *"Debian"* ]]; then
        apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release \
            git \
            wget \
            unzip
    elif [[ $OS == *"CentOS"* ]] || [[ $OS == *"Red Hat"* ]] || [[ $OS == *"Rocky"* ]] || [[ $OS == *"Alma"* ]]; then
        yum install -y \
            yum-utils \
            device-mapper-persistent-data \
            lvm2 \
            git \
            wget \
            unzip
    elif [[ $OS == *"Fedora"* ]]; then
        dnf install -y \
            dnf-plugins-core \
            git \
            wget \
            unzip
    fi
    
    success "Dependências instaladas"
}

# Instalar Docker
install_docker() {
    log "Instalando Docker..."
    
    if command -v docker &> /dev/null; then
        success "Docker já está instalado"
        return
    fi
    
    if [[ $OS == *"Ubuntu"* ]] || [[ $OS == *"Debian"* ]]; then
        # Instalar Docker no Ubuntu/Debian
        curl -fsSL https://download.docker.com/linux/$(echo $ID | tr '[:upper:]' '[:lower:]')/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$(echo $ID | tr '[:upper:]' '[:lower:]') \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
    elif [[ $OS == *"CentOS"* ]] || [[ $OS == *"Red Hat"* ]] || [[ $OS == *"Rocky"* ]] || [[ $OS == *"Alma"* ]]; then
        # Instalar Docker no CentOS/RHEL
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
    elif [[ $OS == *"Fedora"* ]]; then
        # Instalar Docker no Fedora
        dnf -y install dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi
    
    # Iniciar e habilitar Docker
    systemctl start docker
    systemctl enable docker
    
    # Adicionar usuário atual ao grupo docker
    if [[ $SUDO_USER ]]; then
        usermod -aG docker $SUDO_USER
    fi
    
    success "Docker instalado e configurado"
}

# Instalar Docker Compose
install_docker_compose() {
    log "Instalando Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        success "Docker Compose já está instalado"
        return
    fi
    
    # Baixar a última versão do Docker Compose
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    success "Docker Compose instalado"
}

# Criar estrutura de diretórios
create_directories() {
    log "Criando estrutura de diretórios..."
    
    mkdir -p /opt/openvpn-audit/{html,html/css,html/webfonts,html/pages,nginx,postgres,backup}
    
    success "Estrutura de diretórios criada"
}

# Baixar e instalar Font Awesome localmente
install_font_awesome() {
    log "Instalando Font Awesome localmente..."
    
    # Baixar Font Awesome
    cd /tmp
    wget https://use.fontawesome.com/releases/v6.4.2/fontawesome-free-6.4.2-web.zip
    unzip fontawesome-free-6.4.2-web.zip
    
    # Copiar arquivos CSS e webfonts
    cp -r fontawesome-free-6.4.2-web/css/* /opt/openvpn-audit/html/css/
    cp -r fontawesome-free-6.4.2-web/webfonts/* /opt/openvpn-audit/html/webfonts/
    
    # Limpar arquivos temporários
    rm -rf fontawesome-free-6.4.2-web*
    
    success "Font Awesome instalado localmente"
}

# Criar páginas HTML do dashboard (com menus funcionais)
create_dashboard_html() {
    log "Criando dashboard HTML com menus funcionais..."
    
    # Página principal (index.html)
    cat > /opt/openvpn-audit/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard de Auditoria OpenVPN</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="./css/all.min.css" rel="stylesheet">
    <style>
        :root {
            --primary-color: #2c3e50;
            --secondary-color: #3498db;
            --success-color: #27ae60;
            --warning-color: #f39c12;
            --danger-color: #e74c3c;
            --light-bg: #f8f9fa;
        }
        
        body {
            background-color: #f5f7fa;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        
        .sidebar {
            background: linear-gradient(180deg, var(--primary-color), #1a2530);
            color: white;
            height: 100vh;
            position: fixed;
            padding-top: 20px;
            z-index: 1000;
            overflow-y: auto;
        }
        
        .main-content {
            margin-left: 250px;
            padding: 20px;
        }
        
        .card {
            border-radius: 10px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            border: none;
            margin-bottom: 20px;
            transition: transform 0.3s;
        }
        
        .card-header {
            background: linear-gradient(90deg, var(--primary-color), var(--secondary-color));
            color: white;
            border-radius: 10px 10px 0 0 !important;
            font-weight: 600;
        }
        
        .status-badge {
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 500;
        }
        
        .status-ok {
            background-color: rgba(39, 174, 96, 0.2);
            color: var(--success-color);
        }
        
        .status-pendente {
            background-color: rgba(243, 156, 18, 0.2);
            color: var(--warning-color);
        }
        
        .status-expirado {
            background-color: rgba(231, 76, 60, 0.2);
            color: var(--danger-color);
        }
        
        .btn-primary {
            background: linear-gradient(90deg, var(--primary-color), var(--secondary-color));
            border: none;
        }
        
        .stat-card {
            text-align: center;
            padding: 20px;
        }
        
        .stat-number {
            font-size: 2.5em;
            font-weight: 700;
            margin: 10px 0;
        }
        
        .nav-link {
            color: rgba(255,255,255,0.8);
            margin: 5px 0;
            border-radius: 5px;
            transition: all 0.3s;
            text-decoration: none;
        }
        
        .nav-link:hover, .nav-link.active {
            background-color: rgba(255,255,255,0.1);
            color: white;
        }
        
        .search-box {
            background: white;
            border-radius: 30px;
            padding: 5px 15px;
        }
        
        .expired-row {
            background-color: rgba(231, 76, 60, 0.05);
        }
        
        .page-content {
            display: none;
        }
        
        .page-content.active {
            display: block;
        }
    </style>
</head>
<body>
    <!-- Sidebar -->
    <div class="sidebar col-md-2">
        <div class="text-center mb-4">
            <h4><i class="fas fa-shield-alt"></i> OpenVPN Audit</h4>
            <small>Sistema de Auditoria</small>
        </div>
        <hr class="bg-light">
        <ul class="nav flex-column">
            <li class="nav-item">
                <a class="nav-link active" href="#dashboard" onclick="showPage('dashboard', this); return false;">
                    <i class="fas fa-home me-2"></i> Dashboard
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="#usuarios" onclick="showPage('usuarios', this); return false;">
                    <i class="fas fa-users me-2"></i> Usuários
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="#documentos" onclick="showPage('documentos', this); return false;">
                    <i class="fas fa-file-alt me-2"></i> Documentos
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="#alertas" onclick="showPage('alertas', this); return false;">
                    <i class="fas fa-bell me-2"></i> Alertas
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="#relatorios" onclick="showPage('relatorios', this); return false;">
                    <i class="fas fa-chart-bar me-2"></i> Relatórios
                </a>
            </li>
        </ul>
    </div>

    <!-- Main Content -->
    <div class="main-content col-md-10">
        <!-- Dashboard Page -->
        <div id="dashboard-page" class="page-content active">
            <div class="row mb-4">
                <div class="col-md-6">
                    <h2><i class="fas fa-tachometer-alt"></i> Dashboard de Auditoria</h2>
                    <p class="text-muted">Monitoramento e gestão de acessos OpenVPN</p>
                </div>
                <div class="col-md-6 text-end">
                    <div class="search-box d-inline-block me-3">
                        <i class="fas fa-search"></i>
                        <input type="text" class="border-0" placeholder="Buscar usuários..." id="dashboard-search">
                    </div>
                    <button class="btn btn-primary" onclick="showPage('usuarios'); return false;">
                        <i class="fas fa-plus"></i> Novo Usuário
                    </button>
                </div>
            </div>

            <!-- Stats Cards -->
            <div class="row mb-4">
                <div class="col-md-3">
                    <div class="card stat-card">
                        <i class="fas fa-users fa-2x text-primary mb-2"></i>
                        <div class="stat-number">42</div>
                        <div class="stat-label">Total de Usuários</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="card stat-card">
                        <i class="fas fa-check-circle fa-2x text-success mb-2"></i>
                        <div class="stat-number">31</div>
                        <div class="stat-label">Documentação OK</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="card stat-card">
                        <i class="fas fa-exclamation-triangle fa-2x text-warning mb-2"></i>
                        <div class="stat-number">8</div>
                        <div class="stat-label">Pendentes</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="card stat-card">
                        <i class="fas fa-calendar-times fa-2x text-danger mb-2"></i>
                        <div class="stat-number">3</div>
                        <div class="stat-label">Expirados</div>
                    </div>
                </div>
            </div>

            <!-- Main Table -->
            <div class="row">
                <div class="col-12">
                    <div class="card">
                        <div class="card-header">
                            <i class="fas fa-list"></i> Lista de Usuários
                        </div>
                        <div class="card-body">
                            <div class="table-responsive">
                                <table class="table table-hover">
                                    <thead>
                                        <tr>
                                            <th>Login</th>
                                            <th>Data Início</th>
                                            <th>Data Fim</th>
                                            <th>Status Documentação</th>
                                            <th>Ações</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <tr class="expired-row">
                                            <td>carlos.silva</td>
                                            <td>01/01/2023</td>
                                            <td class="text-danger"><strong>31/12/2023</strong></td>
                                            <td><span class="status-badge status-ok">OK</span></td>
                                            <td>
                                                <button class="btn btn-sm btn-outline-danger" data-action="desativar-usuario">
                                                    <i class="fas fa-user-times"></i> Desativar
                                                </button>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>maria.oliveira</td>
                                            <td>15/03/2023</td>
                                            <td>03/01/2024</td>
                                            <td><span class="status-badge status-ok">OK</span></td>
                                            <td>
                                                <button class="btn btn-sm btn-outline-warning" data-action="editar-usuario">
                                                    <i class="fas fa-edit"></i> Editar
                                                </button>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>joao.santos</td>
                                            <td>10/06/2023</td>
                                            <td>07/01/2024</td>
                                            <td><span class="status-badge status-pendente">Faltando</span></td>
                                            <td>
                                                <button class="btn btn-sm btn-outline-info" data-action="lembrar-usuario">
                                                    <i class="fas fa-bell"></i> Lembrar
                                                </button>
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Usuários Page -->
        <div id="usuarios-page" class="page-content">
            <div class="row mb-4">
                <div class="col-md-6">
                    <h2><i class="fas fa-users"></i> Gestão de Usuários</h2>
                    <p class="text-muted">Cadastro e gerenciamento de usuários OpenVPN</p>
                </div>
                <div class="col-md-6 text-end">
                    <button class="btn btn-primary">
                        <i class="fas fa-plus"></i> Novo Usuário
                    </button>
                </div>
            </div>

            <div class="row">
                <div class="col-12">
                    <div class="card">
                        <div class="card-header">
                            <i class="fas fa-list"></i> Lista de Usuários
                        </div>
                        <div class="card-body">
                            <div class="table-responsive">
                                <table class="table table-hover">
                                    <thead>
                                        <tr>
                                            <th>Login</th>
                                            <th>Numero da OS</th>
                                            <th>Data Início</th>
                                            <th>Data Fim</th>
                                            <th>Status</th>
                                            <th>Ações</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <tr>
                                            <td>carlos.silva</td>
                                            <td>OS-12345</td>
                                            <td>01/01/2023</td>
                                            <td>31/12/2023</td>
                                            <td><span class="status-badge status-ok">Ativo</span></td>
                                            <td>
                                                <button class="btn btn-sm btn-outline-primary me-1">
                                                    <i class="fas fa-edit"></i>
                                                </button>
                                                <button class="btn btn-sm btn-outline-danger">
                                                    <i class="fas fa-trash"></i>
                                                </button>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>maria.oliveira</td>
                                            <td>OS-67890</td>
                                            <td>15/03/2023</td>
                                            <td>03/01/2024</td>
                                            <td><span class="status-badge status-ok">Ativo</span></td>
                                            <td>
                                                <button class="btn btn-sm btn-outline-primary me-1">
                                                    <i class="fas fa-edit"></i>
                                                </button>
                                                <button class="btn btn-sm btn-outline-danger">
                                                    <i class="fas fa-trash"></i>
                                                </button>
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Documentos Page -->
        <div id="documentos-page" class="page-content">
            <div class="row mb-4">
                <div class="col-12">
                    <h2><i class="fas fa-file-alt"></i> Documentos</h2>
                    <p class="text-muted">Gestão de documentação dos usuários</p>
                </div>
            </div>

            <div class="row">
                <div class="col-md-6">
                    <div class="card">
                        <div class="card-header">
                            <i class="fas fa-upload"></i> Upload de Documentos
                        </div>
                        <div class="card-body">
                            <div class="mb-3">
                                <label class="form-label">Selecione o usuário</label>
                                <select class="form-select">
                                    <option>Carlos Silva</option>
                                    <option>Maria Oliveira</option>
                                    <option>João Santos</option>
                                </select>
                            </div>
                            <div class="mb-3">
                                <label class="form-label">Tipo de documento</label>
                                <select class="form-select">
                                    <option>RG/CPF</option>
                                    <option>CNH</option>
                                    <option>Documento Assinado</option>
                                </select>
                            </div>
                            <div class="mb-3">
                                <label class="form-label">Arquivo</label>
                                <input type="file" class="form-control">
                            </div>
                            <button class="btn btn-primary">Enviar Documento</button>
                        </div>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="card">
                        <div class="card-header">
                            <i class="fas fa-file-contract"></i> Documentos Pendentes
                        </div>
                        <div class="card-body">
                            <ul class="list-group">
                                <li class="list-group-item d-flex justify-content-between align-items-center">
                                    João Santos - Documento assinado
                                    <span class="badge bg-warning rounded-pill">Pendente</span>
                                </li>
                                <li class="list-group-item d-flex justify-content-between align-items-center">
                                    Ana Pereira - RG/CPF
                                    <span class="badge bg-warning rounded-pill">Pendente</span>
                                </li>
                            </ul>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Alertas Page -->
        <div id="alertas-page" class="page-content">
            <div class="row mb-4">
                <div class="col-12">
                    <h2><i class="fas fa-bell"></i> Alertas e Notificações</h2>
                    <p class="text-muted">Sistema de alertas de expiração e pendências</p>
                </div>
            </div>

            <div class="row">
                <div class="col-md-6">
                    <div class="card">
                        <div class="card-header bg-danger text-white">
                            <i class="fas fa-exclamation-circle"></i> Alertas Críticos
                        </div>
                        <div class="card-body">
                            <div class="alert alert-danger">
                                <strong>Carlos Silva</strong> - Acesso expira hoje (31/12/2023)
                                <div class="mt-2">
                                    <button class="btn btn-sm btn-danger">Desativar Agora</button>
                                    <button class="btn btn-sm btn-outline-secondary">Adiar 7 dias</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="card">
                        <div class="card-header bg-warning text-dark">
                            <i class="fas fa-clock"></i> Alertas de Expiração
                        </div>
                        <div class="card-body">
                            <div class="alert alert-warning">
                                <strong>Maria Oliveira</strong> - Acesso expira em 3 dias (03/01/2024)
                                <div class="mt-2">
                                    <button class="btn btn-sm btn-warning">Enviar Lembrete</button>
                                </div>
                            </div>
                            <div class="alert alert-warning">
                                <strong>João Santos</strong> - Acesso expira em 7 dias (07/01/2024)
                                <div class="mt-2">
                                    <button class="btn btn-sm btn-warning">Enviar Lembrete</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Relatórios Page -->
        <div id="relatorios-page" class="page-content">
            <div class="row mb-4">
                <div class="col-12">
                    <h2><i class="fas fa-chart-bar"></i> Relatórios</h2>
                    <p class="text-muted">Relatórios de auditoria e estatísticas</p>
                </div>
            </div>

            <div class="row">
                <div class="col-md-4">
                    <div class="card">
                        <div class="card-header">
                            <i class="fas fa-chart-pie"></i> Status dos Documentos
                        </div>
                        <div class="card-body text-center">
                            <div style="width: 200px; height: 200px; border-radius: 50%; background: conic-gradient(#27ae60 0% 75%, #f39c12 75% 95%, #e74c3c 95% 100%); margin: 0 auto;"></div>
                            <div class="mt-3">
                                <span class="badge bg-success me-2">OK: 75%</span>
                                <span class="badge bg-warning me-2">Pendente: 20%</span>
                                <span class="badge bg-danger">Expirado: 5%</span>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-8">
                    <div class="card">
                        <div class="card-header">
                            <i class="fas fa-history"></i> Histórico de Acessos
                        </div>
                        <div class="card-body">
                            <div class="table-responsive">
                                <table class="table table-striped">
                                    <thead>
                                        <tr>
                                            <th>Data</th>
                                            <th>Usuário</th>
                                            <th>Ação</th>
                                            <th>Detalhes</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <tr>
                                            <td>22/12/2023 14:30</td>
                                            <td>Carlos Silva</td>
                                            <td><span class="badge bg-success">Acesso Concedido</span></td>
                                            <td>Criação de novo usuário</td>
                                        </tr>
                                        <tr>
                                            <td>22/12/2023 10:15</td>
                                            <td>Maria Oliveira</td>
                                            <td><span class="badge bg-info">Documento Atualizado</span></td>
                                            <td>Upload de RG/CPF</td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Navegação por hash + alternância de páginas
        function showPage(pageName, linkElement) {
            // Atualiza o hash sem rolar a página
            if (pageName && ('#' + pageName) !== window.location.hash) {
                history.replaceState(null, '', '#' + pageName);
            }

            // Esconde todas as páginas
            document.querySelectorAll('.page-content').forEach(function(page) {
                page.classList.remove('active');
            });

            // Mostra a página desejada se existir
            var target = document.getElementById(pageName + '-page');
            if (target) {
                target.classList.add('active');
            }

            // Atualiza navegação ativa
            document.querySelectorAll('.nav-link').forEach(function(link) {
                link.classList.remove('active');
            });

            if (!linkElement) {
                // Tenta encontrar o link correspondente pelo href="#<pageName>"
                linkElement = document.querySelector('.nav-link[href="#' + pageName + '"]');
            }
            if (linkElement) {
                linkElement.classList.add('active');
            }
        }

        function handleHashChange() {
            var hash = (window.location.hash || '#dashboard').replace('#', '');
            showPage(hash);
        }

        // Inicialização
        document.addEventListener('DOMContentLoaded', function() {
            // Inicializa pela rota do hash
            handleHashChange();

            // Ouve mudanças no hash
            window.addEventListener('hashchange', handleHashChange);

            // Handlers básicos dos botões por data-action (simulação)
            document.body.addEventListener('click', function(e) {
                var btn = e.target.closest('button[data-action]');
                if (!btn) return;
                var action = btn.getAttribute('data-action');
                if (action === 'desativar-usuario') {
                    alert('Usuário desativado (simulação).');
                } else if (action === 'editar-usuario') {
                    alert('Abrindo edição do usuário (simulação).');
                } else if (action === 'lembrar-usuario') {
                    alert('Lembrete enviado (simulação).');
                }
            });
        });
    </script>
</body>
</html>
EOF

    success "Dashboard HTML com menus funcionais criado"
}

# Criar arquivo docker-compose.yml com PostgreSQL (corrigido)
create_docker_compose() {
    log "Criando docker-compose.yml com PostgreSQL (corrigido)..."
    
    cat > /opt/openvpn-audit/docker-compose.yml << 'EOF'
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: openvpn_audit_nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./html:/usr/share/nginx/html
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - postgres
    networks:
      - openvpn_audit_network

  postgres:
    image: postgres:15-alpine
    container_name: openvpn_audit_postgres
    environment:
      POSTGRES_DB: openvpn_audit
      POSTGRES_USER: audituser
      POSTGRES_PASSWORD: auditpass123
      POSTGRES_ROOT_PASSWORD: rootpassword123
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    networks:
      - openvpn_audit_network
    command: >
      postgres -c shared_preload_libraries=pg_stat_statements 
      -c pg_stat_statements.track=all 
      -c log_statement=all

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: openvpn_audit_pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@openvpn.local
      PGADMIN_DEFAULT_PASSWORD: admin123
    ports:
      - "5050:80"
    depends_on:
      - postgres
    networks:
      - openvpn_audit_network

volumes:
  postgres_data:

networks:
  openvpn_audit_network:
    driver: bridge
EOF

    success "docker-compose.yml com PostgreSQL criado"
}

# Criar configuração do Nginx (corrigida)
create_nginx_config() {
    log "Criando configuração do Nginx (corrigida)..."
    
    mkdir -p /opt/openvpn-audit/nginx
    
    cat > /opt/openvpn-audit/nginx/default.conf << 'EOF'
server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    location /webfonts/ {
        alias /usr/share/nginx/html/webfonts/;
    }

    location /css/ {
        alias /usr/share/nginx/html/css/;
    }

    location /pages/ {
        alias /usr/share/nginx/html/pages/;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF

    cat > /opt/openvpn-audit/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    error_log   /var/log/nginx/error.log;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    types_hash_max_size 2048;

    include /etc/nginx/conf.d/*.conf;
}
EOF

    success "Configuração do Nginx criada"
}

# Criar script de inicialização
create_startup_script() {
    log "Criando script de inicialização..."
    
    cat > /opt/openvpn-audit/start.sh << 'EOF'
#!/bin/bash

cd /opt/openvpn-audit

# Verificar se Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "Docker não encontrado. Execute o script de instalação primeiro."
    exit 1
fi

# Verificar se Docker Compose está instalado
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose não encontrado. Execute o script de instalação primeiro."
    exit 1
fi

echo "Iniciando serviços OpenVPN Audit..."
docker-compose up -d

echo "Serviços iniciados!"
echo "Dashboard disponível em: http://localhost"
echo "pgAdmin disponível em: http://localhost:5050"
echo "PostgreSQL disponível em: localhost:5432"
EOF

    chmod +x /opt/openvpn-audit/start.sh
    
    cat > /opt/openvpn-audit/stop.sh << 'EOF'
#!/bin/bash

cd /opt/openvpn-audit

echo "Parando serviços OpenVPN Audit..."
docker-compose down

echo "Serviços parados!"
EOF

    chmod +x /opt/openvpn-audit/stop.sh
    
    success "Scripts de inicialização criados"
}

# Criar script de backup
create_backup_script() {
    log "Criando script de backup..."
    
    cat > /opt/openvpn-audit/backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/openvpn-audit/backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="openvpn_audit_backup_$DATE"

echo "Criando backup: $BACKUP_NAME"

# Criar diretório de backup se não existir
mkdir -p $BACKUP_DIR

# Backup do banco de dados PostgreSQL
docker exec openvpn_audit_postgres pg_dump -U audituser -d openvpn_audit > $BACKUP_DIR/${BACKUP_NAME}_database.sql

# Backup dos arquivos HTML
tar -czf $BACKUP_DIR/${BACKUP_NAME}_html.tar.gz -C /opt/openvpn-audit html

# Backup da configuração
tar -czf $BACKUP_DIR/${BACKUP_NAME}_config.tar.gz -C /opt/openvpn-audit nginx docker-compose.yml

echo "Backup concluído: $BACKUP_DIR/$BACKUP_NAME"
EOF

    chmod +x /opt/openvpn-audit/backup.sh
    
    success "Script de backup criado"
}

# Criar arquivo SQL de inicialização para PostgreSQL
create_init_sql() {
    log "Criando script de inicialização do banco de dados PostgreSQL..."
    
    mkdir -p /opt/openvpn-audit/postgres
    
    cat > /opt/openvpn-audit/postgres/init.sql << 'EOF'
-- Criar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Criar tabela de usuários
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    login VARCHAR(100) NOT NULL UNIQUE,
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    status_documentacao VARCHAR(20) NOT NULL CHECK (status_documentacao IN ('OK', 'Faltando')),
    link_rg_cpf VARCHAR(500),
    link_documento_assinado VARCHAR(500),
    notas TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Criar tabela de auditoria
CREATE TABLE IF NOT EXISTS auditoria (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id),
    acao VARCHAR(100) NOT NULL,
    descricao TEXT,
    data_acao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Criar trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_usuarios_updated_at 
    BEFORE UPDATE ON usuarios 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Inserir dados de exemplo
INSERT INTO usuarios (login, data_inicio, data_fim, status_documentacao, notas) VALUES
('carlos.silva', '2023-01-01', '2023-12-31', 'OK', 'Projeto de segurança'),
('maria.oliveira', '2023-03-15', '2024-01-03', 'OK', 'Acesso temporário'),
('joao.santos', '2023-06-10', '2024-01-07', 'Faltando', 'Pendente de assinatura');

-- Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_usuarios_data_fim ON usuarios(data_fim);
CREATE INDEX IF NOT EXISTS idx_usuarios_status ON usuarios(status_documentacao);
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario_id ON auditoria(usuario_id);
EOF

    success "Script de inicialização do banco de dados PostgreSQL criado"
}

# Iniciar serviços
start_services() {
    log "Iniciando serviços..."
    
    cd /opt/openvpn-audit
    
    # Verificar se os containers já estão rodando
    if docker ps | grep -q openvpn_audit; then
        warning "Serviços já estão em execução"
        return
    fi
    
    docker-compose up -d
    
    # Aguardar alguns segundos para os serviços iniciarem
    sleep 15
    
    success "Serviços iniciados com sucesso!"
}

# Criar serviço systemd (opcional)
create_systemd_service() {
    log "Criando serviço systemd (opcional)..."
    
    cat > /etc/systemd/system/openvpn-audit.service << 'EOF'
[Unit]
Description=OpenVPN Audit Dashboard
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/openvpn-audit
ExecStart=/opt/openvpn-audit/start.sh
ExecStop=/opt/openvpn-audit/stop.sh

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    
    success "Serviço systemd criado"
}

# Mostrar informações finais
show_final_info() {
    echo
    echo "=========================================="
    echo "    INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
    echo "=========================================="
    echo
    echo "📁 Diretório de instalação: /opt/openvpn-audit"
    echo "🌐 Dashboard: http://localhost"
    echo "📊 pgAdmin: http://localhost:5050"
    echo "🗄️  PostgreSQL: localhost:5432"
    echo
    echo "📂 Scripts disponíveis:"
    echo "   - /opt/openvpn-audit/start.sh    (iniciar serviços)"
    echo "   - /opt/openvpn-audit/stop.sh     (parar serviços)"
    echo "   - /opt/openvpn-audit/backup.sh   (criar backup)"
    echo
    echo "🔐 Credenciais do PostgreSQL:"
    echo "   - Usuário: audituser"
    echo "   - Senha: auditpass123"
    echo "   - Banco: openvpn_audit"
    echo "   - Superusuário: (senha definida no docker-compose)"
    echo
    echo "🔐 Credenciais do pgAdmin:"
    echo "   - Email: admin@openvpn.local"
    echo "   - Senha: admin123"
    echo
    echo "🔧 Para iniciar os serviços manualmente:"
    echo "   cd /opt/openvpn-audit && docker-compose up -d"
    echo
    echo "📝 Para visualizar logs:"
    echo "   docker-compose logs -f"
    echo
    echo "⚠️  Lembre-se de mudar as senhas padrão em produção!"
    echo
}

# Função principal
main() {
    clear
    echo "=========================================="
    echo "  Instalador Rápido Docker + OpenVPN Audit"
    echo "           (Menus Funcionais)"
    echo "=========================================="
    echo
    
    # Verificar permissões
    check_root
    
    # Detectar sistema operacional
    detect_os
    
    # Confirmar instalação
    echo "Este script irá:"
    echo "1. Atualizar o sistema"
    echo "2. Instalar Docker e Docker Compose"
    echo "3. Criar dashboard de auditoria OpenVPN com menus funcionais"
    echo "4. Configurar containers Nginx, PostgreSQL e pgAdmin"
    echo
    read -p "Deseja continuar? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Instalação cancelada."
        exit 0
    fi
    
    echo
    log "Iniciando instalação..."
    
    # Executar etapas da instalação
    update_system
    install_dependencies
    install_docker
    install_docker_compose
    create_directories
    install_font_awesome
    create_dashboard_html
    create_docker_compose
    create_nginx_config
    create_init_sql
    create_startup_script
    create_backup_script
    create_systemd_service
    start_services
    
    # Mostrar informações finais
    show_final_info
    
    success "Instalação concluída! 🎉"
}

# Executar função principal
main "$@"