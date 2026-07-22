#!/bin/bash

# 配置MySQL服务器以支持PASA

set -e

PROJECT_DIR="${PROJECT_ROOT}"
SPECIES=${1:-"T01"}
DB_NAME="${SPECIES}_pasa"
DB_USER="pasa"
DB_PASS="pasa123"

echo "=========================================="
echo "配置MySQL服务器以支持PASA"
echo "数据库: $DB_NAME"
echo "=========================================="
echo ""

# 检查MySQL是否安装
if ! command -v mysql &> /dev/null; then
    echo "错误: MySQL客户端未找到"
    exit 1
fi

# 尝试启动MySQL服务器（使用conda环境中的MySQL）
MYSQL_SERVER_BIN=""
if [ -f "$HOME/miniconda3/envs/pasa/bin/mysqld" ]; then
    MYSQL_SERVER_BIN="$HOME/miniconda3/envs/pasa/bin/mysqld"
    MYSQL_CLIENT_BIN="$HOME/miniconda3/envs/pasa/bin/mysql"
elif command -v mysqld &> /dev/null; then
    MYSQL_SERVER_BIN=$(which mysqld)
    MYSQL_CLIENT_BIN=$(which mysql)
else
    echo "错误: MySQL服务器未找到"
    echo "请安装MySQL服务器: conda install -n pasa -c conda-forge mysql-server"
    exit 1
fi

echo "1. 检查MySQL服务器状态..."

# 检查MySQL是否已在运行
if mysql -u root -e "SELECT 1" 2>/dev/null; then
    echo "   ✓ MySQL服务器已在运行"
    MYSQL_RUNNING=1
else
    echo "   MySQL服务器未运行，尝试启动..."
    
    # 创建MySQL数据目录
    MYSQL_DATA_DIR="${PROJECT_DIR}/mysql_data"
    mkdir -p "$MYSQL_DATA_DIR"
    
    # 初始化MySQL（如果数据目录为空）
    if [ ! -d "$MYSQL_DATA_DIR/mysql" ]; then
        echo "   初始化MySQL数据目录..."
        $MYSQL_SERVER_BIN --initialize-insecure --datadir="$MYSQL_DATA_DIR" --user=$(whoami) 2>&1 || true
    fi
    
    # 启动MySQL服务器（后台）
    echo "   启动MySQL服务器..."
    nohup $MYSQL_SERVER_BIN --datadir="$MYSQL_DATA_DIR" --user=$(whoami) \
          --socket="${MYSQL_DATA_DIR}/mysql.sock" \
          --pid-file="${MYSQL_DATA_DIR}/mysql.pid" \
          --port=3306 \
          --skip-networking \
          > "${MYSQL_DATA_DIR}/mysql.log" 2>&1 &
    
    MYSQL_PID=$!
    echo "   MySQL服务器已启动 (PID: $MYSQL_PID)"
    
    # 等待MySQL启动
    echo "   等待MySQL启动..."
    sleep 5
    
    # 设置socket路径
    export MYSQL_UNIX_PORT="${MYSQL_DATA_DIR}/mysql.sock"
    
    MYSQL_RUNNING=0
    for i in {1..30}; do
        if $MYSQL_CLIENT_BIN -u root -S "${MYSQL_DATA_DIR}/mysql.sock" -e "SELECT 1" 2>/dev/null; then
            MYSQL_RUNNING=1
            break
        fi
        sleep 1
    done
    
    if [ $MYSQL_RUNNING -eq 1 ]; then
        echo "   ✓ MySQL服务器已启动"
    else
        echo "   ✗ MySQL服务器启动失败"
        echo "   请检查日志: ${MYSQL_DATA_DIR}/mysql.log"
        exit 1
    fi
fi

# 使用socket连接
MYSQL_SOCKET="${MYSQL_DATA_DIR}/mysql.sock"
if [ -f "$MYSQL_SOCKET" ]; then
    MYSQL_CMD="$MYSQL_CLIENT_BIN -u root -S $MYSQL_SOCKET"
else
    MYSQL_CMD="$MYSQL_CLIENT_BIN -u root"
fi

echo ""
echo "2. 创建PASA数据库和用户..."

# 创建数据库
$MYSQL_CMD << SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

if [ $? -eq 0 ]; then
    echo "   ✓ 数据库和用户已创建"
else
    echo "   ✗ 创建数据库失败"
    exit 1
fi

# 更新PASA配置文件
echo ""
echo "3. 更新PASA配置文件..."

CONFIG_FILE="${PROJECT_DIR}/annotation/${SPECIES}/pasa_update/pasa.CONFIG"
CONF_FILE="${PROJECT_DIR}/annotation/${SPECIES}/pasa_update/conf.txt"

# 更新conf.txt
if [ -f "$CONF_FILE" ]; then
    sed -i "s|MYSQLSERVER=.*|MYSQLSERVER=localhost|g" "$CONF_FILE"
    sed -i "s|MYSQL_RW_USER=.*|MYSQL_RW_USER=${DB_USER}|g" "$CONF_FILE"
    sed -i "s|MYSQL_RW_PASSWORD=.*|MYSQL_RW_PASSWORD=${DB_PASS}|g" "$CONF_FILE"
    echo "   ✓ conf.txt已更新"
fi

# 更新pasa.CONFIG
if [ -f "$CONFIG_FILE" ]; then
    sed -i "s|DATABASE=.*|DATABASE=${DB_NAME}|g" "$CONFIG_FILE"
    echo "   ✓ pasa.CONFIG已更新"
fi

echo ""
echo "=========================================="
echo "MySQL配置完成！"
echo "=========================================="
echo ""
echo "数据库信息:"
echo "  数据库名: $DB_NAME"
echo "  用户名: $DB_USER"
echo "  密码: $DB_PASS"
echo ""
echo "MySQL socket: ${MYSQL_DATA_DIR}/mysql.sock"
echo ""
echo "下一步: 运行PASA更新"
echo "  bash scripts/run_pasa_update.sh ${SPECIES}"
echo ""

