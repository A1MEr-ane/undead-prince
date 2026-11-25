extends SceneTree
## 无头测试入口：godot --headless --path . -s tests/run_tests.gd
## 跑完状态树与战役闭环用例，有失败时退出码为 1。

const TestAgentState = preload("res://tests/test_agent_state.gd")
const TestCampaign = preload("res://tests/test_campaign.gd")
const TestBattles = preload("res://tests/test_battles.gd")
const TestBoons = preload("res://tests/test_boons.gd")
const TestCampaignData = preload("res://tests/test_campaign_data.gd")
const TestCampaignFlow = preload("res://tests/test_campaign_flow.gd")


func _init() -> void:
	var suite = TestAgentState.new()
	var failed: int = suite.run_all()
	failed += TestCampaign.new().run_all()
	failed += TestBattles.new().run_all()
	failed += TestBoons.new().run_all()
	failed += TestCampaignData.new().run_all()
	failed += TestCampaignFlow.new().run_all()
	quit(1 if failed > 0 else 0)
