const { createClient } = require('@supabase/supabase-js');
const url = "https://ionszphvxhffqfwlohiv.supabase.co";
const key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvbnN6cGh2eGhmZnFmd2xvaGl2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjMxMzI3NCwiZXhwIjoyMDkxODg5Mjc0fQ.zjJiPnQukevYfyz_CFveLmyHt0jykQWoolEORej233U";
const supabase = createClient(url, key);

async function test() {
  const { data, error } = await supabase.from('sales_orders').select('order_id, status').limit(1);
  if (error) { console.error("Select Error:", error); return; }
  console.log("Got order:", data);

  if (data && data.length > 0) {
    const order_id = data[0].order_id;
    console.log("Updating to pending...");
    const { data: updateData, error: updateError } = await supabase.from('sales_orders').update({ status: 'pending' }).eq('order_id', order_id).select();
    if (updateError) { console.error("Update Error:", updateError); }
    else { console.log("Update Success:", updateData); }
  }
}
test();
