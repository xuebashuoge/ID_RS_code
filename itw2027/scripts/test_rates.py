import math
import unittest
from fractions import Fraction
from rate_model import certificate, support, packing, theorem_design, FAMILIES

class Rates(unittest.TestCase):
    def test_integer_optimum_against_exhaustive_search(self):
        for n in range(6,17):
            r=(n+1)//2;T=2**(n//2)
            for family in FAMILIES:
                for aligned in (True,False):
                    for eps in (Fraction(1,10),Fraction(1,3)):
                        step=r if aligned else 1
                        candidates=[]
                        for m in range(step,r*T+1,step):
                            if m<2 or (family=='rank' and m<5): continue
                            if support(m,family)*((m+r-1)//r-1)<=eps*T:
                                candidates.append(m)
                        d=certificate(n,family,eps,aligned=aligned)
                        self.assertEqual(d['m'] if d else None,max(candidates) if candidates else None)
    def test_support_and_padding(self):
        self.assertEqual(support(168,'exact-threshold'),14028)
        p=packing(42,168,64800,32400)
        self.assertEqual((p['G'],p['padding']),(771,18))
        self.assertAlmostEqual(p['R_eff'],math.log2(168)*771/64800)
        self.assertGreater(p['n_eff'],42/.5)
    def test_vanishing_sequence_and_legacy_design(self):
        for f,K in [('id',65536),('rank',3120),('exact-threshold',6)]:
            d=theorem_design(40,f)
            self.assertEqual(d['K'],K)
            self.assertLessEqual(d['bound'],d['design_bound'])
        for f in FAMILIES:
            d=theorem_design(4096,f,1/64)
            self.assertLess(abs(d['rate']-d['asymptotic']),.02)
    def test_parameter_rejection(self):
        with self.assertRaises(ValueError): certificate(1,'id')
        with self.assertRaises(ValueError): packing(100,10,100,20)
        with self.assertRaises(ValueError): support(100,'exact-threshold',beta=1.5)

if __name__=='__main__': unittest.main()
