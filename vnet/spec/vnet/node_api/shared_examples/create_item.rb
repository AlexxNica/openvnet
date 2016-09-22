# -*- coding: utf-8 -*-

# 'create_events': Array of events after deletion.
# 'create_filter': Filter used when calling create on nodeapi.
# 'create_result': Expected result from call to nodeapi create. (Optional)
# 'query_result': Expected result from call to nodeapi query. (Optional)
# 'events': Should be 'MockEventHandler.handled_events'.

# TODO: Add block that allows the caller to include additional tests. (?)

# TODO: Check if there are event params we're not testing for.

shared_examples 'create item on node_api' do |name, extra_creations = []|
  let(:model_class) { Vnet::Models.const_get(name.to_s.camelize) }
  let(:nodeapi_class) { Vnet::NodeApi.const_get(name.to_s.camelize) }

  let(:all_creations) {
    extra_creations.inject([model_class]) { |creations, extra_name|
      creations << Vnet::Models.const_get(extra_name.to_s.camelize)
    }
  }

  it 'successfully created' do
    pre_counts = all_creations.map { |m_class| m_class.count }
    result = nodeapi_class.execute(:create, create_filter)
    post_counts = all_creations.map { |m_class| m_class.count }

    expect(post_counts).to eq(pre_counts.map { |c| c + 1 })
    expect(result).to include(create_result)

    # TODO: Add query_filter option.
    if result[:uuid]
      model = model_class[result[:uuid]]
    else
      model = model_class[id: result[:id]]
    end

    expect(model).to be_model_and_include(query_result)
    expect(events.size).to eq(create_events.size)

    create_events.each_with_index { |event, index|
      expect(events[index]).to be_event_from_model(model, event.first, event.last)
    }
  end
end
