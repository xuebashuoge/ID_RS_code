"""Integer finite-length RS certificates for L(R,n)=2**(Rn).

No finite-field allocation is needed, even for asymptotic-length calculations.
Threshold means exactly beta one-bits (integer beta), not at-most beta.
"""
import math
from fractions import Fraction
from decimal import Decimal, localcontext, ROUND_FLOOR
from functools import lru_cache

FAMILIES = ('id', 'rank', 'exact-threshold')

def support(m, family, rank=20, beta=2):
    if family == 'id':
        return 1
    if family == 'rank':
        if rank < 0 or rank.bit_length() > m:
            raise ValueError('rank outside the message space')
        return rank + 1
    if family == 'exact-threshold':
        if beta < 1 or int(beta) != beta:
            raise ValueError('exact threshold requires a positive integer beta')
        return math.comb(m, beta) if m >= beta else 0
    raise ValueError(family)

def certificate(n, family, epsilon=Fraction(1, 100), rank=20, beta=2, aligned=True):
    """Largest m for the balanced r,T choice with S(m)(ceil(m/r)-1)/T<=eps.

    Optimal only within this r,T choice; m need not be a multiple of r when
    aligned=False. Fraction comparison avoids floating boundary mistakes.
    """
    if n < 2 or int(n) != n or not 0 < epsilon < 1:
        raise ValueError('n>=2 integer, 0<epsilon<1 required')
    r, T = (n+1)//2, 1 << (n//2)
    eps = Fraction(epsilon)
    step = r if aligned else 1
    min_m = max(1, rank.bit_length() if family == 'rank' else beta if family == 'exact-threshold' else 1)
    lo, hi = (min_m+step-1)//step, r*T//step
    first = lo
    def feasible(j):
        m = j*step
        return support(m,family,rank,beta)*((m+r-1)//r-1)*eps.denominator <= T*eps.numerator
    if not feasible(lo):
        return None
    while lo < hi:
        mid = (lo+hi+1)//2
        if feasible(mid): lo = mid
        else: hi = mid-1
    assert lo >= first
    m = lo*step
    K = (m+r-1)//r
    S = support(m,family,rank,beta)
    return dict(n_t=n,r=r,T=T,K=K,m=m,S=S,rate=math.log2(m)/n,
                bound=float(Fraction(S*(K-1),T)), aligned=aligned)

@lru_cache(maxsize=None)
def design_budget(n, E):
    # Enough precision to retain every integer digit plus >=50 guard digits.
    # Decimal input defines E. Downward enclosure prevents optimistic rounding.
    with localcontext() as ctx:
        ctx.prec=max(80,int(n*.16)+60)
        exponent=Decimal(n)*(Decimal('0.5')-Decimal(str(E)))
        if exponent==exponent.to_integral_value():
            return 1 << int(exponent)
        value=Decimal(2)**exponent
        return int(value.next_minus().next_minus().to_integral_value(rounding=ROUND_FLOOR))

def theorem_design(n, family, E=0.1, rank=20, beta=2):
    """Aligned conservative m*S_upper(m)<=r*2**(n*(1/2-E)), even n.

    Uses a downward-rounded integer budget and exact integer bisection.
    E may depend on n for vanishing-error sequences.
    """
    if n % 2 or not 0 < E < 0.5:
        raise ValueError('even n and 0<E<1/2 required')
    r, T = n//2, 1 << (n//2)
    budget = design_budget(n,E)
    def fits(K):
        if family == 'exact-threshold':
            return K**(beta+1)*r**beta <= math.factorial(beta)*budget
        else:
            return K*(1 if family=='id' else rank+1) <= budget
    if not fits(1): return None
    lo, hi = 1, T
    while lo < hi:
        mid = (lo+hi+1)//2
        if fits(mid): lo=mid
        else: hi=mid-1
    m = r*lo
    S = support(m,family,rank,beta)
    return dict(n_t=n,r=r,T=T,K=lo,m=m,S=S,rate=math.log2(m)/n,E=E,
                bound=float(Fraction(S*(lo-1),T)), design_bound=2.0**(-n*E),
                asymptotic=1/(2*(1+beta)) if family=='exact-threshold' else 0.5)

def packing(n_t, m, N_b, N_i):
    G = N_i//n_t
    if G < 1: raise ValueError('tag exceeds information block')
    n_eff = N_b/G
    return dict(G=G,padding=N_i-G*n_t,R_c=N_i/N_b,
                payload_rate=G*n_t/N_b,n_eff=n_eff,
                R_eff=math.log2(m)/n_eff,
                unpacked_rate=math.log2(m)/N_b,packing_gain=G)
