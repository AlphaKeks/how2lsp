-- Install packer (our plugin manager) automatically if it's not
-- already installed. It will clone the repo as soon as you open
-- neovim. Then re-open neovim and you should have access to various
-- `:Packer` commands. The first one of those that you should run is
-- `:PackerSync` to install all your plugins.
local packer_path = vim.fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if vim.fn.empty(vim.fn.glob(packer_path)) > 0 then
	vim.fn.system({
		"git",
		"clone",
		"--depth",
		"1",
		"https://github.com/wbthomason/packer.nvim",
		packer_path
	})

	vim.cmd.packadd("packer.nvim")
end

-- Make sure all plugins are loaded.
-- To install plugins run :PackerInstall
-- To update your plugins run :PackerUpdate
-- To sync your local versions of all your plugins with their master branch run :PackerSync
--   (this is what you will usually do all the time)
require("packer").startup(function(use)
	-- Let packer update itself
	use("wbthomason/packer.nvim")

	-- SICK THEME
	use({
		"catppuccin/nvim",
		as = "catppuccin"
	})

	-- Treesitter abstraction to easily configure it
	use("nvim-treesitter/nvim-treesitter")

	-- preset LSP configurations + easier to use API read this for
	-- all available language servers:
	--   https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
	use("neovim/nvim-lspconfig")

	-- completion enginge that can pickup from language servers and
	-- other sources
	use({
		"hrsh7th/nvim-cmp",
		requires = {
			-- nvim-cmp requires a snippet enginge to work, even if
			-- you're not gonna use snippets.
			"L3MON4D3/LuaSnip",

			-- These are called "sources" -- they are feeding
			-- autocompletion results into nvim-cmp, which will show
			-- them on your screen.

			"hrsh7th/cmp-buffer", -- This will grab words from your buffer
			"hrsh7th/cmp-nvim-lsp", -- This will grab suggestions from your language server.
		}
	})
end)

--[[ setup plugins HERE ]]--

-- `pcall` returns a boolean + the return value of the function you
-- pass to it. The boolean determines whether the function call
-- succeeded or not without crashing your program if it fails.
local catppuccin_installed, catppuccin = pcall(require, "catppuccin")
if catppuccin_installed then
	-- load the default configuration
	catppuccin.setup()

	-- apply the colorscheme
	vim.cmd.colorscheme("catppuccin")
end

-- You will see this pattern a lot.
local treesitter_installed, treesitter = pcall(require, "nvim-treesitter.configs")
if treesitter_installed then
	treesitter.setup({
		-- Everytime you launch nvim treesitter will make sure these
		-- parsers are installed and up to date.
		ensure_installed = {
			"help",
			"vim",
			"rust",
			"lua",
		},

		-- Use treesitter for indentation as well. This is known to
		-- cause problems in some languages (e.g. python) so you
		-- might need to disable it for certain filetypes.
		-- Docs: https://github.com/nvim-treesitter/nvim-treesitter#indentation
		ident = {
			enable = true
		},

		-- Nice syntax highlighting baby
		highlight = {
			enable = true
		}
	})
end

local lspconfig_installed, lspconfig = pcall(require, "lspconfig")
if lspconfig_installed then
	local function format_on_save(buf_number)
		-- :h autocmds -- "event listeners" if you are familiar with javascript
		-- :h nvim_create_autocmds -- the lua function to create them
		-- :h events -- should be obvious
		-- :h BufWritePre -- just read the help page already
		vim.api.nvim_create_autocmd("BufWritePre", {
			buffer = buf_number,

			-- this gets ran everytime the event fires
			callback = function()
				-- format code using LSP
				vim.lsp.buf.format()
			end
		})
	end

	local function lsp_keymaps(buf_number)
		-- :h vim.keymap.set()
		-- The 3rd argument here can either be a string or a function.
		--   If this is a string, it gets interpreted as a sequence of keypresses.
		--   If this is a function, it will be called when you hit your keycombo.
		vim.keymap.set("n", "gd", vim.lsp.buf.definition)
		vim.keymap.set("n", "gD", vim.lsp.buf.declaration)
		vim.keymap.set("n", "ga", vim.lsp.buf.code_action)
		vim.keymap.set("n", "gr", vim.lsp.buf.rename)

		-- This will show diagnostics on the current line. These are
		-- not necessarily LSP diagnostics, but most of the time they
		-- will be.
		vim.keymap.set("n", "gl", vim.diagnostic.open_float)

		-- This will jump your cursor to the next available
		-- diagnostic and display it.
		vim.keymap.set("n", "gL", vim.diagnostic.goto_next)
	end

	-- The diagnostic API is not exclusive to LSP but heavily used by
	-- it. If you want it to look fancy, you should configure it :)
	-- :h vim.diagnostic.config
	vim.diagnostic.config({
		-- Will display errors on the line they occur in.
		virtual_text = {
			-- Will show which language server/source the diagnostic
			-- message is coming from.
			source = true,

			-- This is a custom prefix that I personally like to
			-- disable, feel free to not change it or change it to
			-- some cool symbol.
			prefix = "",

			-- This will only show error messages, not warnings or
			-- anything. You can still read them with the `gl` keymap
			-- from above, they just won't show inline.
			severity = vim.diagnostic.severity.ERROR
		},

		-- Get rid of annoying underlines when you have errors -- I
		-- find those extremely distracting, feel free to enable them
		-- if you want to.
		underline = false,

		-- Will prioritize important messages (e.g. errors > warnings)
		severity_sort = true,

		-- The float window from `gl`
		float = {
			-- This will enable you to press `gl` again and put your
			-- cursor inside the window so you can move around and
			-- copy stuff. You can go back with `<esc>`, `<C-o>` or
			-- `q`.
			focusable = true,

			-- Always show which diagnostic message come from which
			-- source.
			source = "always",

			-- Funny message at the top of the floating window.
			header = "Diagnostics",

			-- Because we like it fancy.
			border = "rounded"
		}
	})

	-- Use the same look as above for LSP floating windows.
	vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
	vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })

	-- This section will make more sense once we move onto `nvim-cmp`
	-- but just know that this is necessary to get stuff like
	-- auto-imports when using autocompletion.
	local capabilities = vim.lsp.protocol.make_client_capabilities()
	local cmp_installed, cmp_lsp = pcall(require, "cmp_nvim_lsp")
	if cmp_installed then
		capabilities = cmp_lsp.default_capabilities(capabilities)
	end

	-- Now to actually setup your servers. It's always the same pattern of
	--   lspconfig[<SERVER>].setup(options)
	-- Let's say you installed `tsserver` via `npm install -g typescript-language-server`:

	lspconfig["tsserver"].setup({
		-- This function will run when this server attaches to a
		-- buffer. In my case I want to load my keymaps and setup
		-- format on save when this happesn. You can put any code you
		-- want here, of course :)
		on_attach = function(_client, buf_number)
			format_on_save(buf_number)
			lsp_keymaps(buf_number)
		end,

		-- We've seen this -- it's important for `nvim-cmp`
		capabilities = capabilities
	})

	-- ^ This is the same for every language server. Read the
	-- `server_configurations.md` I linked earlier to find out how to
	-- install and configure them; but it's the same pattern every
	-- time.
end

local cmp_installed, cmp = pcall(require, "cmp")
local luasnip_installed, luasnip = pcall(require, "luasnip")
if cmp_installed and luasnip_installed then
	cmp.setup {
		mapping = cmp.mapping.preset.insert {
			-- Confirm a suggestion
			["<cr>"] = cmp.mapping.confirm { select = true },

			-- Force open the completion menu if it's not currently shown
			["<c-space>"] = cmp.mapping.complete(),

			-- Scroll the documentation window 4 lines down
			["<c-j>"] = cmp.mapping.scroll_docs(4),

			-- Scroll the documentation window 4 lines up
			["<c-k>"] = cmp.mapping.scroll_docs(-4),

			-- Select next available suggestion (down)
			["<tab>"] = cmp.mapping(function(fallback)
				if cmp.visible() then cmp.select_next_item()
				else fallback()
				end
			end),

			-- Select previous available suggestion (up)
			["<s-tab>"] = cmp.mapping(function(fallback)
				if cmp.visible() then cmp.select_prev_item()
				else fallback()
				end
			end)
		},

		-- The order of these matter. The results you get are ordered
		-- by the order of the sources in this table. We want LSP
		-- suggestions to have higher priority than buffer words.
		sources = {
			{ name = "nvim_lsp" },

			-- We only want 1 buffer word to be shown at a time, feel
			-- free to change this of course. `keyword_length` will
			-- determine how many characters you need to type before
			-- a word gets suggested.
			{ name = "buffer", max_item_count = 1, keyword_length = 5 }
		},
		formatting = {
			expandable_indicator = false,
			format = function(_, item)
				item.menu = ""

				-- If you have a font with icon support installed you
				-- can use these, they will show up in your
				-- completion menu based on the kind of item you get
				-- suggested. If you don't have such a font or just
				-- simply prefer words, just remove this line and it
				-- will use words instead.
				item.kind = ({
					Text = "", Method = "", Function = "", Constructor = "",
					Field = "", Variable = "", Class = "", Interface = "",
					Module = "", Property = "", Unit = "", Value = "", Enum = "",
					Keyword = "", Snippet = "", Color = "", File = "", Reference = "",
					Folder = "", EnumMember = "", Constant = "", Struct = "",
					Event = "", Operator = "", TypeParameter = "",
				})[item.kind]
				return item
			end
		},
		window = { -- Fancy rounded borders everywhere :D
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered()
	},
	preselect = cmp.PreselectMode.None, -- Don't automatically select the first suggestion.
	snippet = {
		expand = function(args)
			ls.lsp_expand(args.body)
		end
	}
}
end
