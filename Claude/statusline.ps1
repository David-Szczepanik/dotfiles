# 1. Force UTF-8 for both Input (Node stream) and Output (Claude UI)
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    # 2. Read standard input synchronously to prevent pipeline hangs from Node.js
    $inputData = [Console]::In.ReadToEnd()

    if ([string]::IsNullOrWhiteSpace($inputData)) {
        exit 0
    }

    # 3. Parse the JSON
    $session = ConvertFrom-Json $inputData -ErrorAction Stop

    $model = $session.model.display_name
    $model_id = $session.model.id
    $in_tok = $session.context_window.current_usage.input_tokens
    $out_tok = $session.context_window.current_usage.output_tokens
    $cache_write = $session.context_window.current_usage.cache_creation_input_tokens ?? 0
    $cache_read = $session.context_window.current_usage.cache_read_input_tokens ?? 0
    $used = $session.context_window.used_percentage
    $five = $session.rate_limits.five_hour.used_percentage

    $parts = @()
    if ($model) { $parts += $model }

    if ($in_tok -and $out_tok) {
        $in_k = "{0:F1}k" -f ($in_tok / 1000)
        $out_k = "{0:F1}k" -f ($out_tok / 1000)
        $parts += "in:$in_k out:$out_k"

        switch -Regex ($model_id) {
            "opus-4|opus4" { $price_in = 15.00; $price_out = 75.00; $price_cw = 18.75; $price_cr = 1.50 }
            "haiku" { $price_in = 0.80; $price_out = 4.00; $price_cw = 1.00; $price_cr = 0.08 }
            default { $price_in = 3.00; $price_out = 15.00; $price_cw = 3.75; $price_cr = 0.30 }
        }

        $cost = ($in_tok * $price_in + $out_tok * $price_out + $cache_write * $price_cw + $cache_read * $price_cr) / 1000000
        $parts += "`${0:F4}" -f $cost
    }

    if ($used) { $parts += "ctx: {0:F0}%" -f $used }
    if ($five) { $parts += "5h: {0:F0}%" -f $five }

    if ($parts.Count -gt 0) {
        # Write-Output is safer for standard stdout capturing than Write-Host
        Write-Output ($parts -join " | ")
    }
} catch {
    # If it breaks behind the scenes, dump the exact error to a file so we can read it!
    Add-Content -Path "$env:USERPROFILE\.claude\status_error.log" -Value "$(Get-Date) - Error: $_`nInput Data: $inputData"
}
