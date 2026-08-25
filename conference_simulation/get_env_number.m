function value = get_env_number(name, default_value)
%GET_ENV_NUMBER Read a finite numeric environment override.

    raw = strtrim(getenv(name));
    if isempty(raw)
        value = default_value;
        return;
    end

    value = str2double(raw);
    if ~isfinite(value)
        error('Environment variable %s must be a finite number; got "%s".', ...
            name, raw);
    end
end
