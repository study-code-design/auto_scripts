" ==============================
" 基础设置
" ==============================

" 必须放在最前面：退出 vi 兼容模式，启用现代 Vim 行为
set nocompatible

" 启用文件类型检测和插件
filetype plugin indent on

" 启用语法高亮
syntax on

" 显示行号
set number

" 相对行号（可选，按需开启）
" set relativenumber

" 搜索高亮 & 智能大小写
set hlsearch
set incsearch
set ignorecase
set smartcase

" 退格键行为：允许跨行、删除缩进和行首
set backspace=indent,eol,start

" 使用系统剪贴板（需 Vim 编译时支持 +clipboard）
if has('clipboard')
    set clipboard=unnamedplus
endif

" 自动缩进 & 智能缩进
set autoindent
set smartindent

" Tab 和缩进设置（推荐用空格）
set tabstop=4
set shiftwidth=4
set expandtab
set softtabstop=4

" 保存时自动去除行尾空格（可选）
autocmd BufWritePre * %s/\s\+$//e

" 更好的命令行体验
set wildmenu
set showcmd
set ruler
set laststatus=2

" 高亮当前行（可选）
set cursorline

" 拆分窗口时，新窗口在下方/右侧打开
set splitbelow
set splitright

" 启用鼠标支持（终端需支持）
set mouse=a

" ==============================
" 性能与文件处理
" ==============================

" 快速保存和退出
nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>a

" 快速退出
nnoremap <C-q> :q<CR>
nnoremap <C-w> :wq<CR>

" 忽略某些文件类型备份
set nobackup
set nowritebackup
set noswapfile

" 识别更多文件类型（如 .gitignore）
au BufNewFile,BufRead .gitignore setf gitconfig

" ==============================
" 插件管理（使用 vim-plug）
" ==============================

" 自动安装 vim-plug 如果不存在
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

" 主题
Plug 'morhetz/gruvbox'

" 文件树
Plug 'preservim/nerdtree'

" 代码注释
Plug 'tpope/vim-commentary'

" 括号/标签高亮匹配
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'

" Git 集成
Plug 'tpope/vim-fugitive'

" 模糊查找文件（需安装 fzf）
" Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
" Plug 'junegunn/fzf.vim'

" C++/Python 等语言支持（可选 LSP）
" Plug 'neoclide/coc.nvim', {'branch': 'release'}

call plug#end()

" ==============================
" 主题与 UI
" ==============================

" 设置配色方案（需插件已安装）
set termguicolors
colorscheme gruvbox
set background=dark

" 状态栏美化（简单版）
set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [POS=%l,%v][%p%%]
