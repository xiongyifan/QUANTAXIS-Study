#!/usr/bin/env python
# coding: utf-8

# In[1]:


import QUANTAXIS as QA
from QAPUBSUB.consumer import subscriber  # 消费者
from QAPUBSUB.producer import publisher  # 生产者
import threading  # 在线程中运行消费者，防止线程阻塞
import json  # 消费者接收的数据是文本，转成json
import pandas as pd  # json转成DataFrame


# In[2]:


# 1. 账户准备
user = QA.QA_User(username='admin', password='admin')  # 账号密码跟81页面登录的账号密码一致
# portfolio_cookie就像是组合的id
port = user.new_portfolio(portfolio_cookie='x1')
# account_cookie就像是账户的id，init_cash是账户的初始资金，market_type为市场类型，QA中通过market_type预设了交易规则，例如期货允许t0等，与国内的交易规则一致。
acc = port.new_account(account_cookie='test_local_simpledeal', init_cash=100000, market_type=QA.MARKET_TYPE.FUTURE_CN)


# In[3]:


# 2. 发单操作方法
def sendorder(code, trade_price, trade_amount, trade_towards, trade_time):
	acc.receive_simpledeal(
		code=code,
		trade_price=trade_price,
		trade_amount=trade_amount,
		trade_towards=trade_towards,
		trade_time=trade_time)


# In[4]:


# 3. 策略
market_data_list = []  # 存储历史数据
# 下面订阅数据时会指定on_data为回调函数，接到数据就会执行on_data
def on_data(a, b, c, data):
    # 数据准备
    bar = json.loads(data)
    market_data_list.append(bar)
    # 日线date格式是2019-01-01
    market_data_df = pd.DataFrame(market_data_list).set_index('date', drop=False)

    # 计算指标
    ind = QA.QA_indicator_MA(market_data_df, 2, 4)  # 计算MA2和MA4
    print(ind)
    
    # 策略逻辑
    MA2 = ind.iloc[-1]['MA2']  # 取最新的MA2
    MA4 = ind.iloc[-1]['MA4']  # 取最新的MA4
    code = bar['code']  # 合约代码
    trade_price = bar['close']  # 最新收盘价
    trade_amount = 1  # 1手
    trade_time = bar['date'] + ' 00:00:00'  # 由于日线date的格式是2019-01-01，所以要加后面的时间，否则无法计算指标，后面的问题章节有详细说明。
    code_hold_available = acc.hold_available.get(code, 0)  # 合约目前的持仓情况
    if MA2 > MA4:
        if code_hold_available == 0:
            print('买多')
            sendorder(code, trade_price, trade_amount, QA.ORDER_DIRECTION.BUY_OPEN, trade_time)
        elif code_hold_available > 0:
            print('持有')
        else:
            print('平空')
            sendorder(code, trade_price, trade_amount, QA.ORDER_DIRECTION.BUY_CLOSE, trade_time)
    elif MA4 > MA2:
        if code_hold_available == 0:
            print('卖空')
            sendorder(code, trade_price, trade_amount, QA.ORDER_DIRECTION.SELL_OPEN, trade_time)
        elif code_hold_available < 0:
            print('持有')
        else:
            print('平多')
            sendorder(code, trade_price, trade_amount, QA.ORDER_DIRECTION.SELL_CLOSE, trade_time)
    else:
        print('不操作')


# In[5]:


# 4. 订阅数据
sub = subscriber(exchange='x1')  # Exchange名为x1，在15672页面能看到
sub.callback=on_data  # 指定回调函数
threading.Thread(target=sub.start).start()  # 开线程执行订阅，防止线程阻塞，后面的发布代码无法执行


# In[6]:


# 5. 数据获取并推送数据
# 获取
df = QA.QA_fetch_get_future_day('tdx', 'RBL8', '2019-08-01', '2019-08-30')
# 推送
pub = publisher(exchange='x1')  # 跟订阅的Exchange一致
for idx, item in df.iterrows():
    pub.pub(item.to_json())  # 每行数据换成json，pub出去，上面的on_data就会收到，开始执行策略。


# In[8]:


# 6. 查看结果
risk = QA.QA_Risk(acc)
performance = QA.QA_Performance(acc)


# In[9]:


acc.history_table  # 交易记录


# In[10]:


risk.plot_assets_curve()  # 资产曲线


# In[11]:


performance.pnl  # 盈利情况


# In[12]:


# 7. 保存结果
risk.save()


# In[13]:


acc.save()

