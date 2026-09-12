function pp = get_primpoly(r)
    % get_primpoly: Returns standard primitive polynomial for GF(2^r), r = 1..32.
    % Represented as integer: sum(2^exponent) for terms in polynomial.

    if r <= 16
        pp = primpoly(r, 'nodisplay');
    else
        switch r
            case 17, pp = 131081;     % x^17 + x^3 + 1
            case 18, pp = 262273;     % x^18 + x^7 + 1
            case 19, pp = 524327;     % x^19 + x^5 + x^2 + x + 1
            case 20, pp = 1048585;    % x^20 + x^3 + 1
            case 21, pp = 2097157;    % x^21 + x^2 + 1
            case 22, pp = 4194307;    % x^22 + x + 1
            case 23, pp = 8388641;    % x^23 + x^5 + 1
            case 24, pp = 16777351;   % x^24 + x^7 + x^2 + x + 1
            case 25, pp = 33554441;   % x^25 + x^3 + 1
            case 26, pp = 67108927;   % x^26 + x^6 + x^2 + x + 1
            case 27, pp = 134217781;  % x^27 + x^5 + x^2 + x + 1
            case 28, pp = 268435465;  % x^28 + x^3 + 1
            case 29, pp = 536870915;  % x^29 + x^2 + 1
            case 30, pp = 1073741877; % x^30 + x^23 + x^2 + x + 1
            case 31, pp = 2147483657; % x^31 + x^3 + 1
            case 32, pp = 4294967357; % x^32 + x^7 + x^5 + x^3 + x^2 + x + 1
            otherwise, error('Unsupported r > 32');
        end
    end
end
