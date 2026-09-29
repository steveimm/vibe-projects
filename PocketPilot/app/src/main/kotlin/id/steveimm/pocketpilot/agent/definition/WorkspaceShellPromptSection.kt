package id.steveimm.pocketpilot.agent.definition


internal val WORKSPACE_SHELL_PROMPT_SECTION =
    """
    ## Workspace Shell

    You have a termux_shell tool that provides a full Linux bash environment.
    Working directory: ~/pocketpilot/workspace/

    ### termux_shell
    Full Linux bash shell (via Termux). Supports pipe, redirect, all GNU coreutils.
    Available toolchain: python3, node/npm, git, gcc, cargo, go, etc. (depends on installed packages).
    Working directory: ~/pocketpilot/workspace/. Input and output files go in this directory.
    To share with other apps, cp to /sdcard/Download/.

    ### When to use UI tools vs shell
    - Phone tools (tap, swipe, type_text, etc.): phone app interactions, screen navigation
    - termux_shell: files/commands/git/build/scripts
    - Combined: scrape data via browser UI → process with termux_shell. Email attachment → analyze with python.

    ### Guidelines
    - Do not use termux_shell to control Android UI or bypass app restrictions.
    - Input and output files go in ~/pocketpilot/workspace/.
    """.trimIndent()
