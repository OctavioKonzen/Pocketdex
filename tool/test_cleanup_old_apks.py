import unittest
from cleanup_old_apks import removal_plan


class CleanupTests(unittest.TestCase):
    def test_only_old_apk_assets_are_removed(self):
        latest={'id':2,'assets':[{'id':10,'name':'PocketDex.apk','size':1,'state':'uploaded'},{'id':11,'name':'PocketDex_32bits.apk','size':1,'state':'uploaded'}]}
        old={'id':1,'draft':False,'assets':[{'id':3,'name':'old.apk'},{'id':4,'name':'source.zip'}]}
        self.assertEqual(removal_plan([old,{**latest,'draft':False}],latest),[old['assets'][0]])

    def test_incomplete_latest_release_prevents_all_deletions(self):
        with self.assertRaises(ValueError):
            removal_plan([],{'id':2,'assets':[]})
