import importlib.util
import unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('live_viewer',Path(__file__).with_name('viewer.py'))
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
class FrameTests(unittest.TestCase):
 def setUp(self):
  self.task={'id':'task-1'};self.meta={'taskID':'task-1','bundle':'net.iosipa.oldbili','source':'UIView.layer.renderInContext','detached':True,'width':320,'height':460,'capturedAt':100}
 def test_real_matching_frame(self):self.assertTrue(v.valid_frame(self.meta,self.task,101))
 def test_ios6_numeric_bool(self):self.meta['detached']=1;self.assertTrue(v.valid_frame(self.meta,self.task,101))
 def test_stale_not_live(self):self.assertFalse(v.valid_frame(self.meta,self.task,108))
 def test_other_task_not_live(self):self.assertFalse(v.valid_frame(self.meta,{'id':'task-2'},101))
 def test_wrong_source_not_live(self):self.meta['source']='mock';self.assertFalse(v.valid_frame(self.meta,self.task,101))
 def test_visible_window_rejected(self):self.meta['detached']=False;self.assertFalse(v.valid_frame(self.meta,self.task,101))
 def test_future_clock_rejected(self):self.assertFalse(v.valid_frame(self.meta,self.task,80))
class ExecutionTests(unittest.TestCase):
 def test_summary_without_video_frame(self):
  self.assertTrue(v.valid_execution({'version':1,'source':'phone-execution-data','capturedAt':100,'tasks':[{'kind':'summarize','id':'x','input':'text'}]}))
 def test_all_supported_tasks(self):
  self.assertTrue(v.valid_execution({'version':1,'source':'phone-execution-data','capturedAt':100,'tasks':[{'kind':k,'id':k} for k in ('review','illustrate','summarize','oldbili')]}))
 def test_untrusted_source(self):
  self.assertFalse(v.valid_execution({'version':1,'source':'mock','capturedAt':100,'tasks':[]}))
 def test_unknown_kind(self):
  self.assertFalse(v.valid_execution({'version':1,'source':'phone-execution-data','capturedAt':100,'tasks':[{'kind':'arbitrary-file','id':'x'}]}))
if __name__=='__main__':unittest.main()
