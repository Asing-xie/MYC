import { Test } from '@nestjs/testing';
import { AppModule } from './app.module';

describe('AppModule', () => {
  it('compiles all module dependencies', async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    expect(moduleRef).toBeDefined();
    await moduleRef.close();
  });
});
