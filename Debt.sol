pragma solidity>=0.4.24 <0.6.11;
pragma experimental ABIEncoderV2;

import "./Table.sol";

contract Debt
{
    // event
    //event RegisterEvent(int256 ret, string account, uint256 asset_value);
    //event TransferEvent(int256 ret, string from_account, string to_account, uint256 amount);

    enum COMPANY_TYPE {BANK, OTHER}
    struct Company
    {
        COMPANY_TYPE cType;
    }

    mapping(address => Company) public companies;

    constructor() public
    {
        // 构造函数中创建debt表
        createTable();
    }

    /*
    描述 : 公司注册
    参数 ：
            cType: 公司类型
    返回值：
            无
    */

    function register(uint cType) public
    {
        companies[msg.sender].cType = COMPANY_TYPE(cType);
    }

    string id = "0";
    function createTable() private
    {
        TableFactory tf = TableFactory(0x1001);
        // 应收账款表, key : account, field : asset_value
        // |主码   |债权人     |债务人      |还款日期     |挂起(主码)|金额    |
        // |------|-----------|-----------|-------------|---------|-------|
        // |id    |creditor   |debtor     |ddl          |pending  |value  |
        // |string|address    |address    |uint256      |address  |uint256|
        //
        // 创建表
        tf.createTable("debt", "id", "creditor,debtor,ddl,pending,value");
    }

    function openTable() private returns(Table)
    {
        TableFactory tf = TableFactory(0x1001);
        Table table = tf.openTable("debt");
        return table;
    }

    struct Debt
    {
        address creditor;
        address debtor;
        uint256 ddl;
        address pending;
        uint256 value;
    }

    /*
    描述 : 查询相关debt
    参数 ：
            无

    返回值：
            参数一： 成功返回0, 账户不存在返回-1
            参数二： 第一个参数为0时有效，debt
    */
    function select() public returns (int256, Debt [] memory)
    {
        // 打开表
        Table table = openTable();
        // 查询
        Condition condition;

        condition = table.newCondition();
        condition.EQ("creditor", int256(msg.sender));
        Entries entries0 = table.select(id, condition);

        condition = table.newCondition();
        condition.EQ("debtor", int256(msg.sender));
        Entries entries1 = table.select(id, condition);

        int256 total_size = entries0.size() + entries1.size();
        Debt[] memory debt_list;
        if (total_size == 0)
        {
            return (-1, debt_list);
        }
        debt_list = new Debt[](uint256(total_size));
        int256 i = 0;
        Entry entry;

        for (; i < entries0.size(); ++i)
        {
            entry = entries1.get(i);
            debt_list[uint256(i)].creditor = address(entry.getInt("creditor"));
            debt_list[uint256(i)].debtor = address(entry.getInt("debtor"));
            debt_list[uint256(i)].ddl = uint256(entry.getInt("ddl"));
            debt_list[uint256(i)].pending = address(entry.getInt("pending"));
            debt_list[uint256(i)].value = uint256(entry.getInt("value"));
        }

        for (; i < entries1.size(); ++i)
        {
            entry = entries1.get(i);
            debt_list[uint256(i)].creditor = address(entry.getInt("creditor"));
            debt_list[uint256(i)].debtor = address(entry.getInt("debtor"));
            debt_list[uint256(i)].ddl = uint256(entry.getInt("ddl"));
            debt_list[uint256(i)].pending = address(entry.getInt("pending"));
            debt_list[uint256(i)].value = uint256(entry.getInt("value"));
        }

        return (0, debt_list);
    }

    /*
    描述 : 查询相关debt(作为债务人)
    参数 ：
            债务人地址，还款日期

    返回值：
            参数一： 成功返回0, 账户不存在返回-1
            参数二： 第一个参数为0时有效，当前欠款
    */
    function selectAsCreditor(address creditor, address debtor, uint256 ddl, uint256 value) public returns (int256, uint256)
    {
        // 打开表
        Table table = openTable();
        // 查询
        Condition condition;

        condition = table.newCondition();
        condition.EQ("creditor", int256(creditor));
        condition.EQ("debtor", int256(debtor));
        condition.EQ("ddl", int256(ddl));
        condition.EQ("pending", int256(pending));
        Entries entries0 = table.select(id, condition);

        int256 total_size = entries0.size();
        if (total_size == 0)
        {
            return (-1, 0);
        }
        Entry entry;
        entry = entries1.get(i);
        uint256 ret_value = uint256(entry.getInt("value"));
        return (0, ret_value);
    }

    /*
    描述 :  债权人发起，（债权人，债务人，还款日期）如有则直接修改value，否则插入一条新记录
    参数 ：
            债权人地址，债务人地址，还款日期，金额

    返回值：
            参数一： 存在相同元组返回0，不存在返回1，修改失败返回-1，添加失败返回-2
            参数二： 当前记录中的欠款数额
    */
    function addTransaction(address creditor, address debtor, uint256 ddl, uint256 value) public returns(int256, uint256){
        int256 ret_code = 0;
        int256 ret= 0;
        // 打开表
        Table table = openTable();

        Debt[] memory debt_list;
        (ret, now_value) = selectAsCreditor(debtor, ddl, value);

        if(ret == -1){
            Entry entry = table.newentry();
            entry.set("creditor", creditor);
            entry.set("debtor", debtor);
            entry.set("ddl", ddl);
            entry.set("pending", 0);
            entry.set("value", value);

            int count = table.insert(id, entry);
            if(count == 1){
                ret_code = 1;
            }
            else{
                ret_code = -2;
            }
        }
        else{
            Entry entry = table.newentry();
            entry.set("creditor", creditor);
            entry.set("debtor", debtor);
            entry.set("ddl", ddl);
            entry.set("pending", pending);
            entry.set("value", value + now_value);

            Condition condition = table.newCondition();
            condition.EQ("creditor", int256(creditor));
            condition.EQ("debtor", int256(debtor));
            condition.EQ("ddl", int256(ddl));
            condition.EQ("pending", int256(pending));

            int count = table.update(id, entry, condition);
            if(count == 1){
                ret_code = 0;
            }
            else{
                ret_code = -1;
            }
        }
        return (ret_code, value + now_value);
    }


    /*
    描述 :  债权人发起，向银行账户申请转移债券，设置pending为银行账户
    参数 ：
            债权人地址，债务人地址，还款日期

    返回值：
            参数一： 成功则返回0，若没有可抵消数据则返回-1，可抵消数据>1返回-2，修改失败返回-3
    */
    function mortgage(address creditor, address debtor, uint256 ddl) public returns(int256){
        int256 ret_code = 0;
        int256 ret= 0;
        // 打开表
        Table table = openTable();
        // 查询
        Condition condition;
        condition.EQ("creditor", int256(creditor));
        condition.EQ("debtor", int256(debtor));
        condition.EQ("ddl", int256(ddl));
        condition.EQ("pending", 0);
        Entries entries0 = table.select(id, condition);
        uint256 value = entries0[0].getUInt("value");
        int256 total_size = entries0.size();
        if (total_size == 0)
        {
            return -1;
        }
        else if(total_size > 1){
            return -2;
        }
        Entry entry = table.newentry();
        entry.set("creditor", creditor);
        entry.set("debtor", debtor);
        entry.set("ddl", ddl);
        entry.set("pending", 1);
        entry.set("value", value);

        Condition condition = table.newCondition();
        condition.EQ("creditor", int256(creditor));
        condition.EQ("debtor", int256(debtor));
        condition.EQ("ddl", int256(ddl));
        condition.EQ("pending", 0);

        int count = table.update(id, entry, condition);
        if(count == 1){
            return 0;
        }
        else{
            return -3;
        }
    }


    /*
    描述 :  银行可以取消pending（设为0）将债权人改为自己
    参数 ：
            债权人地址，债务人地址，还款日期

    返回值：
            参数一： 成功则返回0，若没有可抵消数据则返回-1，可抵消数据>1返回-2，修改失败返回-3
    */
    function redemption(address creditor, address debtor, uint256 ddl) public returns(int256){
        int256 ret_code = 0;
        int256 ret= 0;
        // 打开表
        Table table = openTable();
        // 查询
        Condition condition;
        condition.EQ("creditor", int256(creditor));
        condition.EQ("debtor", int256(debtor));
        condition.EQ("ddl", int256(ddl));
        condition.EQ("pending", 1);
        Entries entries0 = table.select(id, condition);
        uint256 value = entries0[0].getUInt("value");
        int256 total_size = entries0.size();
        if (total_size == 0)
        {
            return -1;
        }
        else if(total_size > 1){
            return -2;
        }
        Entry entry = table.newentry();
        entry.set("creditor", creditor);
        entry.set("debtor", debtor);
        entry.set("ddl", ddl);
        entry.set("pending", 0);
        entry.set("value", value);

        Condition condition = table.newCondition();
        condition.EQ("creditor", int256(creditor));
        condition.EQ("debtor", int256(debtor));
        condition.EQ("ddl", int256(ddl));
        condition.EQ("pending", 1);

        int count = table.update(id, entry, condition);
        if(count == 1){
            return 0;
        }
        else{
            return -3;
        }
    }
    
    /*
    描述 :  功能三：债权人发起，减少记录金额，插入一条新记录金额为减少的金额（“插入”同样按照功能一的方式先做判断，看是修改还是插入）
    参数 ：
            被转让债权人地址，转让债权人地址，债务人地址，还款日期，转让金额

    返回值：
            参数一： 转让成功返回0，因指定债权记录不存在转让失败返回-1，因指定债权金额不足转让失败返回-2，数据库操作异常返回-3
    */
    function creditAssignment(address originCreditor, address destinationCreditor, address debtor, uint256 ddl, uint256 assignmentValue) public returns int256 {
        int count = 0;
        // 打开表
        Table table = openTable();

        Condition condition1 = table.newCondition();
        condition1.EQ("creditor", int256(originCreditor));
        condition1.EQ("debtor", int256(debtor));
        condition1.EQ("ddl", int256(ddl));

        Entries entries =table.select(id, condition1);
        if (entries.size() == 0) {  //指定债权不存在
            return -1;
        }
        Entry entry1 = entries.get(0);
        uint256 originValue = uint256(entry1.getInt("value"));
        if (originValue < assignmentValue) {  //指定债权金额不足
            return -2;
        }
        else if (originValue == assignmentValue) {  //债权金额与转让金额相等
            //删除旧债权记录
            count = table.remove(id,condition1);    
            if (count == 0) {     //数据库操作异常
                return -3;
            }
            //新增转让债权人的新债权记录
            Entry entry2 = table.newEntry();
            entry2.set("creditor", destinationCreditor));
            entry2.set("debtor", debtor);
            entry2.set("ddl", int256(ddl));
            entry2.set("pending", 0);
            entry2.set("value", int256(assignmentValue));
            count = table.insert(id, entry2);
            if (count == 0) {     //数据库操作异常
                return -3;
            }
        }
        else {  //债权金额大于转让金额
            //删除旧债权记录
            count = table.remove(id,condition1);    
            if (count == 0) {     //数据库操作异常
                return -3;
            }
            //新增被转让债权人的新债权记录
            Entry entry3 = table.newEntry();
            entry3.set("creditor", originCreditor));
            entry3.set("debtor", debtor);
            entry3.set("ddl", ddl);
            entry3.set("pending", 0);
            entry3.set("value", originValue - assignmentValue);
            count = table.insert(id, entry3);
            if (count == 0) {     //数据库操作异常
                return -3;
            }
            //新增转让债权人的新债权记录
            Entry entry4 = table.newEntry();
            entry4.set("creditor", destinationCreditor));
            entry4.set("debtor", debtor);
            entry4.set("ddl", ddl);
            entry4.set("pending", 0);
            entry4.set("value", assignmentValue);
            count = table.insert(id, entry4);
            if (count == 0) {     //数据库操作异常
                return -3;
            }
        }
        return 0;
    }

    /*
    描述 :  功能四：债权人发起，（判断时间）删除一条记录
    参数 ：
            债权人地址，债务人地址，还款日期

    返回值：
            参数一： 删除成功返回0，指定债权记录不存在返回-1，数据库操作异常返回-2
    */
    function delete(address creditor, address debtor, uint256 ddl) public returns int256 {
        int count = 0;
        // 打开表
        Table table = openTable();

        Condition condition1 = table.newCondition();
        condition1.EQ("creditor", int256(creditor));
        condition1.EQ("debtor", int256(debtor));
        condition1.EQ("ddl", int256(ddl));

        Entries entries =table.select(id, condition1);
        if (entries.size() == 0) {  //指定债权记录不存在
            return -1;
        }

        count = table.remove(id,condition1);    
        if (count == 0) {     //数据库操作异常
            return -3;
        }
        return 0;
    }

}

