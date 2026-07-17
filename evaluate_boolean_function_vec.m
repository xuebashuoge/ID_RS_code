function res = evaluate_boolean_function_vec(b, func_type, params)
    % evaluate_boolean_function: Computes the boolean function
    % 
    % Inputs:
    %   b         - Binary array [N x (r*K)] (b(:, 1) is MSB)
    %   func_type - String defining the family
    %   params    - Struct holding specific parameters
    %
    % Output:
    %   res       - [N x 1] logical array of 1s or 0s
    
    switch lower(func_type)
        case 'id'
            % Constant weight / identification
            % all(..., 2) ensures the entire row matches the target
            res = all(b == params.target, 2);
            
        case 'exact-threshold'
            % h_beta(b) = 1 iff sum(b) = beta
            res = (sum(b, 2) == params.beta);
            
        case 'at-most-threshold'
            % htilde_beta(b) = 1 iff sum(b) <= beta
            res = (sum(b, 2) <= params.beta);
            
        case 'bit-query'
            % f_bit^t(b) = b_t
            res = (b(:, params.t) == 1);
            
        case 'and-subset'
            % f_AND^{S_k}(b) = product of bits in chosen subset
            res = (prod(b(:, params.S_k), 2) == 1);
            
        case 'rank'
            % f_rank^r(b) = 1 iff int(b) <= rank
            m = size(b, 2);
            weights = 2 .^ ((m-1):-1:0);
            int_vals = sum(b .* weights, 2);
            res = (int_vals <= params.rank);
            
        otherwise
            error('Unknown boolean function type.');
    end
end